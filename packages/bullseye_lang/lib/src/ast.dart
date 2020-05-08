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

class VoidLiteralNode extends ExprNode {
  VoidLiteralNode(FileSpan span) : super(span);
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

class BeginEndNode extends ExprNode {
  final List<ExprNode> body;

  BeginEndNode(FileSpan span, this.body) : super(span);
}
class ParenExprNode extends ExprNode {
  final ExprNode inner;

  ParenExprNode(FileSpan span, this.inner) : super(span);
}

class ArgListNode extends Node {
  final List<ArgNode> args;

  ArgListNode(FileSpan span, this.args) : super(span);
}

class ArgNode extends Node {
  final IdNode name;
  final ExprNode value;

  ArgNode(FileSpan span, this.name, this.value) : super(span);
}

class ParamListNode extends Node {
  final List<ParamNode> params;

  ParamListNode(FileSpan span, this.params) : super(span);
}

class ParamNode extends Node {
  final PatternNode pattern;
  final ExprNode defaultValue;

  ParamNode(FileSpan span, this.pattern, this.defaultValue) : super(span);
}

abstract class PatternNode extends Node {
  PatternNode(FileSpan span) : super(span);
}

abstract class TypeNode extends Node {
  TypeNode(FileSpan span) : super(span);
}
