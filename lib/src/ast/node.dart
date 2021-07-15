import 'package:source_span/source_span.dart';

abstract class Node {
  final FileSpan span;

  Node(this.span);
}
