import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';
import 'expression.dart';

abstract class CallExpression extends Expression {
  final List<Argument> arguments;

  CallExpression(List<Token> comments, FileSpan span, this.arguments)
      : super(comments, span);
}

class Argument extends Node {
  final Expression expression;

  Argument._(List<Token> comments, FileSpan span, this.expression)
      : super(comments, span);

  factory Argument(Expression expression) {
    return new Argument._(expression.comments, expression.span, expression);
  }
}

class NamedArgument extends Argument {
  final Identifier name;

  NamedArgument(
      List<Token> comments, FileSpan span, this.name, Expression expression)
      : super._(comments, span, expression);
}

class MemberCallExpression extends CallExpression {
  final MemberExpression target;

  MemberCallExpression(List<Token> comments, FileSpan span,
      List<Argument> arguments, this.target)
      : super(comments, span, arguments);
}

class NamedCallExpression extends CallExpression {
  final Identifier name;

  NamedCallExpression(
      List<Token> comments, FileSpan span, List<Argument> arguments, this.name)
      : super(comments, span, arguments);
}

class IndirectCallExpression extends CallExpression {
  final Expression callee;

  IndirectCallExpression(List<Token> comments, FileSpan span,
      List<Argument> arguments, this.callee)
      : super(comments, span, arguments);
}
