import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

abstract class Node {
  final List<Token> comments;
  final FileSpan span;

  Node(this.comments, this.span);
}
