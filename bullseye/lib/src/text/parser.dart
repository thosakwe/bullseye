import 'package:bullseye/bullseye.dart';

class Parser {
  final List<BullseyeException> exceptions = [];
  final Scanner scanner;
  final ScannerIterator tokens;

  Parser(this.scanner) : tokens = scanner.iterator {
    exceptions.addAll(scanner.exceptions);
  }
}
