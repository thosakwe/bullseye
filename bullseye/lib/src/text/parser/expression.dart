import 'package:bullseye/bullseye.dart';

class ExpressionParser extends PrattParser<Expression> {
  ExpressionParser(Parser parser) : super(parser) {
    addPrefixParselets();
    addInfixParselets();
  }

  @override
  Expression parse([int precedence = 0]) {
    var target = super.parse(precedence), span = target?.span;
    if (target == null) return target;

    var args = <Argument>[];
    var canParseWithoutName = true;
    var arg = parseArgument(canParseWithoutName);

    while (arg != null) {
      canParseWithoutName = canParseWithoutName || arg is NamedArgument;
      args.add(arg);
      arg = parseArgument(canParseWithoutName);
    }

    if (args.isEmpty) {
      return target;
    } else {
      target = target.innermost;

      if (target is MemberExpression) {
        return new MemberCallExpression([], span, args, target);
      } else if (target is Identifier) {
        return new NamedCallExpression([], span, args, target);
      } else {
        return new IndirectCallExpression([], span, args, target);
      }
    }
  }

  Argument parseArgument(bool canParseWithoutName) {
    if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
      var id = new Identifier([], parser.current);

      if (parser.peek()?.type == TokenType.equals && parser.moveNext()) {
        var equals = parser.current;
        var expr = parse();
        if (expr != null) {
          return new NamedArgument(
              [], id.span.expand(equals.span).expand(expr.span), id, expr);
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              equals.span,
              "Missing expression after ':' for named argument '${id.name}'."));
          return null;
        }
      } else {
        return new Argument(id);
      }
    } else if (!canParseWithoutName) {
      var expr = parse();
      if (expr == null) return null;
      return new Argument(expr);
    } else {
      return null;
    }
  }

  void addPrefixParselets() {
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

  void addInfixParselets() {
    InfixParselet<Expression> arithmetic = (p, prec, left, token) {
      var right = p.expressionParser.parse(prec - 1);
      if (right != null) {
        return new ArithmeticExpression([],
            left.span.expand(token.span).expand(right.span),
            left,
            right,
            token);
      } else {
        p.exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            token.span, "Missing expression after '${token.span.text}'."));
        return null;
      }
    };

    addInfix(TokenType.times, arithmetic);
    addInfix(TokenType.div, arithmetic);
    addInfix(TokenType.mod, arithmetic);
    addInfix(TokenType.plus, arithmetic);
    addInfix(TokenType.minus, arithmetic);
  }
}
