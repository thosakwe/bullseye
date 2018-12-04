import 'package:bullseye/bullseye.dart';
export 'parser/parser.dart';

class Parser extends ScannerIterator {
  final List<BullseyeException> exceptions = [];
  ExpressionParser expressionParser;
  FunctionParser functionParser;

  Parser(Scanner scanner) : super(scanner) {
    expressionParser = new ExpressionParser(this);
    functionParser = new FunctionParser(this);
    exceptions.addAll(scanner.exceptions);
  }

  UnitLiteral parseUnit() {
    if (peek()?.type == TokenType.lParen && moveNext()) {
      var lParen = current;

      if (!moveNext()) {
        exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            lParen.span, "Expected ')' after '(', found end-of-file instead."));
      } else if (current.type != TokenType.rParen) {
        exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            lParen.span,
            "Expected ')' after '(', found '${current.span.text}' instead."));
      } else {
        return new UnitLiteral(lParen.span.expand(current.span));
      }
    }
    
    return null;
  }
}
