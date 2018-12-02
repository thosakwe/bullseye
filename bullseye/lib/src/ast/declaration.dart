import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

class CompilationUnit extends Node {
  CompilationUnit(List<Token> comments, FileSpan span) : super(comments, span);
}

abstract class TopLevelDeclaration extends AnnotatedNode {
  TopLevelDeclaration(
      List<Annotation> annotations, List<Token> comments, FileSpan span)
      : super(annotations, comments, span);
}

class FunctionDeclaration extends TopLevelDeclaration {
  final Identifier name;
  final ParameterList parameterList;
  final Expression body;

  FunctionDeclaration(List<Annotation> annotations, List<Token> comments,
      FileSpan span, this.name, this.parameterList, this.body)
      : super(annotations, comments, span);
}

class ParameterList extends Node {
  ParameterList(List<Token> comments, FileSpan span) : super(comments, span);
}

class Parameter extends AnnotatedNode {
  final Identifier name;

  Parameter(List<Annotation> annotations, List<Token> comments, FileSpan span,
      this.name)
      : super(annotations, comments, span);
}
