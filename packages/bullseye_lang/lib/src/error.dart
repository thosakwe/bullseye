import 'package:io/ansi.dart';
import 'package:source_span/source_span.dart';

class BullseyeError {
  final FileSpan span;
  final BullseyeErrorSeverity severity;
  final String message;

  BullseyeError(this.span, this.severity, this.message);

  static String severityToString(BullseyeErrorSeverity severity) {
    switch (severity) {
      case BullseyeErrorSeverity.error:
        return wrapWith('error', [styleBold, red]);
      case BullseyeErrorSeverity.warning:
        return wrapWith('warning', [styleBold, yellow]);
      case BullseyeErrorSeverity.lint:
        return wrapWith('lint', [styleBold, blue]);
      default:
        throw ArgumentError();
    }
  }

  @override
  String toString() =>
      '${severityToString(severity)}: ${span.start.toolString}: $message';
}

enum BullseyeErrorSeverity { error, warning, lint }
