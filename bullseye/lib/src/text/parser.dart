import 'dart:collection';
import 'package:bullseye/bullseye.dart';
export 'parser/parser.dart';

class Parser extends ScannerIterator {
  final List<BullseyeException> exceptions = [];
  DeclarationParser declarationParser;
  ExpressionParser expressionParser;
  FunctionParser functionParser;

  final Queue<Token> _errant = new Queue();

  Parser(Scanner scanner) : super(scanner) {
    declarationParser = new DeclarationParser(this);
    expressionParser = new ExpressionParser(this);
    functionParser = new FunctionParser(this);
    exceptions.addAll(scanner.exceptions);
  }

  CompilationUnit parse() => declarationParser.parseCompilationUnit();

  void markErrant([Token token]) {
    _errant.addLast(token ?? current);
  }

  void flush() {
    if (_errant.isNotEmpty) {
      var span = _errant.map((t) => t.span).reduce((a, b) => a.expand(b));
      _errant.clear();
      exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error, span, "Unexpected text."));
    }
  }

  UnitLiteral parseUnit() {
    if (peek()?.type == TokenType.lParen && moveNext()) {
      var lParen = current;

      if (peek()?.type == TokenType.rParen && moveNext()) {
        return new UnitLiteral(lParen.span.expand(current.span));
      } else if (done) {
        exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            lParen.span, "Expected ')' after '(', found end-of-file instead."));
      } else {
        movePrevious();
      }
    }

    return null;
  }
}
