import 'package:source_span/source_span.dart';

abstract class Node {
  final FileSpan span;

  Node(this.span);
}

class CompilationUnitNode extends Node {
  final List<DirectiveNode> directives;
  final List<DeclNode> decls;

  CompilationUnitNode(FileSpan span, this.directives, this.decls) : super(span);
}

abstract class DirectiveNode extends Node {
  DirectiveNode(FileSpan span) : super(span);
}

class ImportDirectiveNode extends DirectiveNode {
  final bool isExport;
  final StringLiteralNode path;
  final List<ImportModifierNode> modifiers;

  ImportDirectiveNode(FileSpan span, this.isExport, this.path, this.modifiers)
      : super(span);
}

class ImportModifierNode extends Node {
  final bool isHide;
  final List<IdExprNode> names;

  ImportModifierNode(FileSpan span, this.isHide, this.names) : super(span);
}

abstract class DeclNode extends Node {
  DeclNode(FileSpan span) : super(span);
}

class LetDeclNode extends DeclNode {
  final IdExprNode name;
  final ParamListNode paramList;
  final ExprNode value;

  LetDeclNode(FileSpan span, this.name, this.paramList, this.value)
      : super(span);
}

class TypeDeclNode extends DeclNode {
  final IdExprNode id;
  final List<IdExprNode> params;
  final TypeNode type;

  TypeDeclNode(FileSpan span, this.id, this.params, this.type) : super(span);
}

abstract class ExprNode extends Node {
  ExprNode(FileSpan span) : super(span);
}

class IdExprNode extends ExprNode {
  String _name;

  IdExprNode(FileSpan span, [this._name]) : super(span);

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

class StringLiteralNode extends ExprNode {
  final List<StringPartNode> parts;

  StringLiteralNode(FileSpan span, this.parts) : super(span);
}

abstract class StringPartNode extends Node {
  StringPartNode(FileSpan span) : super(span);
}

class TextStringPartNode extends StringPartNode {
  final String text;

  TextStringPartNode(FileSpan span, this.text) : super(span);
}

class InterpolationStringPartNode extends StringPartNode {
  final ExprNode expr;

  InterpolationStringPartNode(FileSpan span, this.expr) : super(span);
}

class AwaitExprNode extends ExprNode {
  final ExprNode target;

  AwaitExprNode(FileSpan span, this.target) : super(span);
}

class PropertyExprNode extends ExprNode {
  final ExprNode target;
  final IdExprNode property;

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
  final IdExprNode name;
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
  final IdExprNode name;
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

class IdPatternNode extends PatternNode {
  final IdExprNode id;

  IdPatternNode(FileSpan span, this.id) : super(span);
}

class IgnoredPatternNode extends PatternNode {
  IgnoredPatternNode(FileSpan span) : super(span);
}

class AliasedPatternNode extends PatternNode {
  final PatternNode target;
  final IdExprNode id;

  AliasedPatternNode(FileSpan span, this.target, this.id) : super(span);
}

class VoidPatternNode extends PatternNode {
  VoidPatternNode(FileSpan span) : super(span);
}

class ExprPatternNode extends PatternNode {
  final ExprNode expr;

  ExprPatternNode(FileSpan span, this.expr) : super(span);
}

class ParenPatternNode extends PatternNode {
  final PatternNode inner;

  ParenPatternNode(FileSpan span, this.inner) : super(span);
}

abstract class TypeNode extends Node {
  TypeNode(FileSpan span) : super(span);
}

class TypeRefNode extends TypeNode {
  final IdExprNode name;

  TypeRefNode(FileSpan span, this.name) : super(span);
}

// TODO: Other types
