import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

abstract class Node {
  final List<Token> comments;
  final FileSpan span;

  Node(this.comments, this.span);
}

class AnnotatedNode extends Node {
  final List<Annotation> annotations;

  AnnotatedNode(this.annotations, List<Token> comments, FileSpan span)
      : super(comments, span);
}

class UnitLiteral extends Node {
  UnitLiteral(FileSpan span) : super([], span);
}
