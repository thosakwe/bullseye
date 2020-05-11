import 'package:bullseye_lang/bullseye_lang.dart';
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

  T accept<T>(DirectiveVisitor<T> visitor);
}

class ImportDirectiveNode extends DirectiveNode {
  final bool isExport;
  final StringLiteralNode path;
  final List<ImportModifierNode> modifiers;

  ImportDirectiveNode(FileSpan span, this.isExport, this.path, this.modifiers)
      : super(span);

  @override
  T accept<T>(DirectiveVisitor<T> visitor) =>
      visitor.visitImportDirective(this);
}

class ImportModifierNode extends Node {
  final bool isHide;
  final List<IdExprNode> names;

  ImportModifierNode(FileSpan span, this.isHide, this.names) : super(span);
}

abstract class DeclNode extends Node {
  DeclNode(FileSpan span) : super(span);

  T accept<T>(DeclVisitor<T> visitor);
}

class LetDeclNode extends DeclNode {
  final IdExprNode name;
  final ParamListNode paramList;
  final ExprNode value;

  LetDeclNode(FileSpan span, this.name, this.paramList, this.value)
      : super(span);

  @override
  T accept<T>(DeclVisitor<T> visitor) => visitor.visitLetDecl(this);
}

class TypeDeclNode extends DeclNode {
  final IdExprNode id;
  final List<IdExprNode> params;
  final TypeNode type;

  TypeDeclNode(FileSpan span, this.id, this.params, this.type) : super(span);

  @override
  T accept<T>(DeclVisitor<T> visitor) => visitor.visitTypeDecl(this);
}

abstract class ExprNode extends Node {
  ExprNode(FileSpan span) : super(span);

  T accept<T>(ExprVisitor<T> visitor);
}

class IdExprNode extends ExprNode {
  String _name;

  IdExprNode(FileSpan span, [this._name]) : super(span);

  String get name => _name ??= span.text;

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitIdExpr(this);
}

class IntLiteralNode extends ExprNode {
  final int value;

  IntLiteralNode(FileSpan span, this.value) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitIntLiteral(this);
}

class DoubleLiteralNode extends ExprNode {
  final double value;

  DoubleLiteralNode(FileSpan span, this.value) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitDoubleLiteral(this);
}

class VoidLiteralNode extends ExprNode {
  VoidLiteralNode(FileSpan span) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitVoidLiteral(this);
}

class StringLiteralNode extends ExprNode {
  final List<StringPartNode> parts;

  StringLiteralNode(FileSpan span, this.parts) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitStringLiteral(this);
}

abstract class StringPartNode extends Node {
  StringPartNode(FileSpan span) : super(span);

  T accept<T>(StringPartVisitor<T> visitor);
}

class TextStringPartNode extends StringPartNode {
  final String text;

  TextStringPartNode(FileSpan span, this.text) : super(span);

  @override
  T accept<T>(StringPartVisitor<T> visitor) =>
      visitor.visitTextStringPart(this);
}

class InterpolationStringPartNode extends StringPartNode {
  final ExprNode expr;

  InterpolationStringPartNode(FileSpan span, this.expr) : super(span);

  @override
  T accept<T>(StringPartVisitor<T> visitor) =>
      visitor.visitInterpolationStringPart(this);
}

class AwaitExprNode extends ExprNode {
  final ExprNode target;

  AwaitExprNode(FileSpan span, this.target) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitAwaitExpr(this);
}

class PropertyExprNode extends ExprNode {
  final ExprNode target;
  final IdExprNode property;

  PropertyExprNode(FileSpan span, this.target, this.property) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitPropertyExpr(this);
}

class ThrowExprNode extends ExprNode {
  final ExprNode target;

  ThrowExprNode(FileSpan span, this.target) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitThrowExpr(this);
}

class CallExprNode extends ExprNode {
  final ExprNode target;
  final ArgListNode args;

  CallExprNode(FileSpan span, this.target, this.args) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitCallExpr(this);
}

class LetInExprNode extends ExprNode {
  final IdExprNode name;
  final ParamListNode paramList;
  final ExprNode value;
  final ExprNode body;

  LetInExprNode(FileSpan span, this.name, this.paramList, this.value, this.body)
      : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitLetInExpr(this);
}

class BeginEndExprNode extends ExprNode {
  final List<ExprNode> body;

  BeginEndExprNode(FileSpan span, this.body) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitBeginEndExpr(this);
}

class ParenExprNode extends ExprNode {
  final ExprNode inner;

  ParenExprNode(FileSpan span, this.inner) : super(span);

  @override
  T accept<T>(ExprVisitor<T> visitor) => visitor.visitParenExpr(this);
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

  T accept<T>(PatternVisitor<T> visitor);
}

class IdPatternNode extends PatternNode {
  final IdExprNode id;

  IdPatternNode(FileSpan span, this.id) : super(span);

  @override
  T accept<T>(PatternVisitor<T> visitor) => visitor.visitIdPattern(this);
}

class IgnoredPatternNode extends PatternNode {
  IgnoredPatternNode(FileSpan span) : super(span);

  @override
  T accept<T>(PatternVisitor<T> visitor) => visitor.visitIgnoredPattern(this);
}

class AliasedPatternNode extends PatternNode {
  final PatternNode target;
  final IdExprNode id;

  AliasedPatternNode(FileSpan span, this.target, this.id) : super(span);

  @override
  T accept<T>(PatternVisitor<T> visitor) => visitor.visitAliasedPattern(this);
}

class VoidPatternNode extends PatternNode {
  VoidPatternNode(FileSpan span) : super(span);

  @override
  T accept<T>(PatternVisitor<T> visitor) => visitor.visitVoidPattern(this);
}

class ExprPatternNode extends PatternNode {
  final ExprNode expr;

  ExprPatternNode(FileSpan span, this.expr) : super(span);

  @override
  T accept<T>(PatternVisitor<T> visitor) => visitor.visitExprPattern(this);
}

class ParenPatternNode extends PatternNode {
  final PatternNode inner;

  ParenPatternNode(FileSpan span, this.inner) : super(span);

  @override
  T accept<T>(PatternVisitor<T> visitor) => visitor.visitParenPattern(this);
}

abstract class TypeNode extends Node {
  TypeNode(FileSpan span) : super(span);

  T accept<T>(TypeVisitor<T> visitor);
}

class TypeRefNode extends TypeNode {
  final IdExprNode name;

  TypeRefNode(FileSpan span, this.name) : super(span);

  @override
  T accept<T>(TypeVisitor<T> visitor) => visitor.visitTypeRef(this);
}

// TODO: Other types
