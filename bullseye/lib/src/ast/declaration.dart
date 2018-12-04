import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

class CompilationUnit extends Node {
  final List<TopLevelDeclaration> topLevelDeclarations;

  CompilationUnit(
      List<Token> comments, FileSpan span, this.topLevelDeclarations)
      : super(comments, span);
}

abstract class TopLevelDeclaration extends AnnotatedNode {
  TopLevelDeclaration(
      List<Annotation> annotations, List<Token> comments, FileSpan span)
      : super(annotations, comments, span);
}

class LetBinding extends Node {
  final Identifier identifier;
  final Expression value;

  LetBinding(List<Token> comments, FileSpan span, this.identifier, this.value)
      : super(comments, span);
}

class Block extends Node {
  final List<LetBinding> letBindings;
  final Expression returnValue;

  Block(List<Token> comments, FileSpan span, this.letBindings, this.returnValue)
      : super(comments, span);
}

class BeginEndExpression extends Expression {
  final Block block;

  BeginEndExpression(List<Token> comments, FileSpan span, this.block)
      : super(comments, span);
}

class FunctionDeclaration extends TopLevelDeclaration {
  final Identifier name;
  final ParameterList parameterList;
  final Block body;

  FunctionDeclaration(List<Annotation> annotations, List<Token> comments,
      FileSpan span, this.name, this.parameterList, this.body)
      : super(annotations, comments, span);
}

class ParameterList extends Node {
  final List<Parameter> parameters;
  ParameterList(List<Token> comments, FileSpan span, this.parameters)
      : super(comments, span);
}

class Parameter extends AnnotatedNode {
  final Identifier name;

  Parameter(List<Annotation> annotations, List<Token> comments, FileSpan span,
      this.name)
      : super(annotations, comments, span);
}
