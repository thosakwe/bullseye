import 'package:source_span/source_span.dart';

abstract class Node {
  final FileSpan span;

  Node(this.span);
}

abstract class ExprNode extends Node {
  ExprNode(FileSpan span) : super(span);
}

class IdNode extends ExprNode {
  String _name;

  IdNode(FileSpan span) : super(span);

  String get name => _name ??= span.text;
}

class IntLiteralNode extends ExprNode {
  final int value;

  IntLiteralNode(FileSpan span, this.value) : super(span);
}

class DoubleLiteralNode extends ExprNode {
  final double value;

  DoubleLiteralNode(FileSpan span, this.value) : super(span);
}

class AwaitExprNode extends ExprNode {
  final ExprNode target;

  AwaitExprNode(FileSpan span, this.target) : super(span);
}

class PropertyExprNode extends ExprNode {
  final ExprNode target;
  final IdNode property;

  PropertyExprNode(FileSpan span, this.target, this.property) : super(span);
}

class ThrowExprNode extends ExprNode {
  final ExprNode target;

  ThrowExprNode(FileSpan span, this.target) : super(span);
}

class CallExprNode extends ExprNode {
  final ExprNode target;
  final ArgListNode args;

  CallExprNode(FileSpan span, this.target, this.args) : super(span);
}

class LetInNode extends ExprNode {
  final IdNode name;
  final ParamListNode paramList;
  final ExprNode value;
  final ExprNode body;

  LetInNode(FileSpan span, this.name, this.paramList, this.value, this.body)
      : super(span);
}

class ArgListNode extends Node {}
