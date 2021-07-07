import 'package:source_span/source_span.dart';

import 'node.dart';

abstract class Expr extends Node {
  Expr(FileSpan span) : super(span);
}
