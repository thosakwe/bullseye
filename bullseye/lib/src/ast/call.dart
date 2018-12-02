import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';
import 'expression.dart';

abstract class CallExpression extends Expression {
  final List<Expression> positionalArguments;

  final List<NamedArgument> namedArguments;

  CallExpression(List<Token> comments, FileSpan span, this.positionalArguments,
      this.namedArguments)
      : super(comments, span);
}

class NamedArgument extends Node {
  final Identifier name;
  final Expression expression;

  NamedArgument(List<Token> comments, FileSpan span, this.name, this.expression)
      : super(comments, span);
}

class MemberCallExpression extends CallExpression {
  final Expression object;
  final Identifier name;

  MemberCallExpression(
      List<Token> comments,
      FileSpan span,
      List<Expression> positionalArguments,
      List<NamedArgument> namedArguments,
      this.object,
      this.name)
      : super(comments, span, positionalArguments, namedArguments);
}

class NamedCallExpression extends CallExpression {
  final Identifier name;

  NamedCallExpression(
      List<Token> comments,
      FileSpan span,
      List<Expression> positionalArguments,
      List<NamedArgument> namedArguments,
      this.name)
      : super(comments, span, positionalArguments, namedArguments);
}

class IndirectCallExpression extends CallExpression {
  final Expression callee;

  IndirectCallExpression(
      List<Token> comments,
      FileSpan span,
      List<Expression> positionalArguments,
      List<NamedArgument> namedArguments,
      this.callee)
      : super(comments, span, positionalArguments, namedArguments);
}
