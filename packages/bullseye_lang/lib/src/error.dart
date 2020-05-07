import 'package:source_span/source_span.dart';

class BullseyeError {
  final FileSpan span;
  final BullseyeErrorSeverity severity;
  final String message;

  BullseyeError(this.span, this.severity, this.message);
}

enum BullseyeErrorSeverity { error, warning, lint }
