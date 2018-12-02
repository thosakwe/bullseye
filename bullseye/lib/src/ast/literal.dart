import 'dart:math' as math;
import 'package:bullseye/bullseye.dart';
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
            int.parse(token.match[1]) * math.pow(10, int.parse(token.match[2])),
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
