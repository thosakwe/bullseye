import 'package:source_span/source_span.dart';

class BullseyeException implements Exception {
  final BullseyeExceptionSeverity severity;
  final FileSpan span;
  final String message;

  BullseyeException(this.severity, this.span, this.message);

  @override
  String toString() {
    var b = new StringBuffer();

    switch (severity) {
      case BullseyeExceptionSeverity.info:
        b.write('info');
        break;
      case BullseyeExceptionSeverity.hint:
        b.write('hint');
        break;
      case BullseyeExceptionSeverity.warning:
        b.write('warning');
        break;
      case BullseyeExceptionSeverity.error:
        b.write('error');
        break;
    }

    b.write(': ');
    b.write(span.start.toolString);
    b.write(': ');
    b.write(message);
    return b.toString();
  }
}

enum BullseyeExceptionSeverity { info, hint, warning, error }
