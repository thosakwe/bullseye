import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';
import 'expression.dart';

class MemberExpression extends Expression {
  final Expression object;
  final Identifier name;
  final Token op;

  MemberExpression(
      List<Token> comments, FileSpan span, this.object, this.name, this.op)
      : super(comments, span);

  bool get isNullCoerced => op.type == TokenType.nonNull;

  bool get isNullCoalescing => op.type == TokenType.nullableDot;

  bool get isNormal => !isNullCoerced && !isNormal;
}
