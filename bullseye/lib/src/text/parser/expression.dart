import 'package:bullseye/bullseye.dart';

class ExpressionParser extends PrattParser<Expression> {
  ExpressionParser(Parser parser) : super(parser) {
    addPrefix(
      TokenType.double$,
      (p, token) => new DoubleLiteral(token, [], token.span),
    );
    addPrefix(
      TokenType.doubleScientific,
      (p, token) => new DoubleScientificLiteral(token, [], token.span),
    );
    addPrefix(
      TokenType.int$,
      (p, token) => new IntLiteral(token, [], token.span),
    );
    addPrefix(
      TokenType.intScientific,
      (p, token) => new IntScientificLiteral(token, [], token.span),
    );
    addPrefix(
      TokenType.id,
      (p, token) => new Identifier([], token),
    );
    addPrefix(
      TokenType.lParen,
      (p, token) {
        var innermost = p.expressionParser.parse();
        if (innermost == null) {
          p.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              token.span,
              "Expected expression after."));
        } else if (p.moveNext()) {
          var rParen = p.current;
          if (rParen.type == TokenType.rParen) {
            return new ParenthesizedExpression(
                innermost.comments,
                token.span.expand(innermost.span).expand(rParen.span),
                innermost);
          } else {
            p.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                token.span,
                "Expected expression after '(', found '${rParen.span.text}' instead."));
          }
        } else {
          p.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              token.span,
              "Expected expression after '(', found end-of-file instead."));
        }
      },
    );
  }
}
