import 'dart:math' as math;
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';
import 'expression.dart';

abstract class Literal<T> extends Expression {
  T constantValue;

  Literal(List<Token> comments, FileSpan span) : super(comments, span);

  bool get hasConstantValue => constantValue != null;
}

abstract class NumberLiteral<T extends num> extends Literal<T> {
  @override
  final T constantValue;

  NumberLiteral(this.constantValue, List<Token> comments, FileSpan span)
      : super(comments, span);
}

@deprecated
class NullLiteral extends Literal<Null> {
  NullLiteral(List<Token> comments, FileSpan span) : super(comments, span);

  @override
  bool get hasConstantValue => true;
}

class BoolLiteral extends Literal<bool> {
  final Token token;

  BoolLiteral(List<Token> comments, FileSpan span, this.token)
      : super(comments, span) {
    constantValue = token.span.text == 'true';
  }
}

class BinaryLiteral extends NumberLiteral<int> {
  final Token token;

  BinaryLiteral(this.token, List<Token> comments, FileSpan span)
      : super(int.parse(token.match[1], radix: 2), comments, span);
}

class OctalLiteral extends NumberLiteral<int> {
  final Token token;

  OctalLiteral(this.token, List<Token> comments, FileSpan span)
      : super(int.parse(token.match[1], radix: 8), comments, span);
}

class HexLiteral extends NumberLiteral<int> {
  final Token token;

  HexLiteral(this.token, List<Token> comments, FileSpan span)
      : super(int.parse(token.match[1], radix: 16), comments, span);
}

class IntLiteral extends NumberLiteral<int> {
  final Token token;

  IntLiteral(this.token, List<Token> comments, FileSpan span)
      : super(int.parse(token.span.text), comments, span);
}

class IntScientificLiteral extends NumberLiteral<int> {
  final Token token;

  IntScientificLiteral(this.token, List<Token> comments, FileSpan span)
      : super(
            int.parse(token.match[1]) *
                math.pow(10, int.parse(token.match[2])).toInt(),
            comments,
            span);
}

class DoubleLiteral extends NumberLiteral<double> {
  final Token token;

  DoubleLiteral(this.token, List<Token> comments, FileSpan span)
      : super(double.parse(token.span.text), comments, span);
}

class DoubleScientificLiteral extends NumberLiteral<double> {
  final Token token;

  DoubleScientificLiteral(this.token, List<Token> comments, FileSpan span)
      : super(
            double.parse(token.match[1]) *
                math.pow(10, int.parse(token.match[2])),
            comments,
            span);
}

class StringLiteral extends Literal<String> {
  final List<StringPart> parts;

  StringLiteral(List<Token> comments, FileSpan span, this.parts)
      : super(comments, span);

  @override
  bool get hasConstantValue => !parts.any((s) => s is InterpolationStringPart);

  @override
  String get constantValue => !hasConstantValue
      ? null
      : parts.map((s) => (s as TextStringPart).text).join();
}

abstract class StringPart {
  final FileSpan span;

  StringPart(this.span);
}

class TextStringPart extends StringPart {
  TextStringPart(FileSpan span) : super(span);

  String get text => span.text;
}

class EscapeStringPart extends TextStringPart {
  final Token token;

  EscapeStringPart(this.token) : super(token.span);

  @override
  String get text {
    if (token.match.groupCount == 0) {
      return token.match[0].substring(1);
    }

    switch (token.match[1]) {
      case 'b':
        return '\b';
      case 'f':
        return '\f';
      case 'n':
        return '\n';
      case 'r':
        return '\r';
      case 't':
        return '\t';
      case '\\':
        return '\\';
      default:
        var ch = int.parse(token.match[1], radix: 16);
        return new String.fromCharCode(ch);
    }
  }
}

class HexStringPart extends TextStringPart {
  final Token token;

  HexStringPart(this.token) : super(token.span);

  @override
  String get text {
    return new String.fromCharCode(int.parse(token.match[1], radix: 16));
  }
}

class InterpolationStringPart extends StringPart {
  final Expression expression;

  InterpolationStringPart(this.expression) : super(expression.span);
}
