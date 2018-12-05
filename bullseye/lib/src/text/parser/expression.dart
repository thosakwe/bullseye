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
    var canParsePositional = true;
    var unit = parser.parseUnit();

    if (unit != null) {
      span = target.span.expand(unit.span);
    } else {
      var arg = parseArgument(canParsePositional);

      while (arg != null) {
        canParsePositional = canParsePositional && arg is! NamedArgument;
        args.add(arg);
        span = span.expand(arg.span);
        arg = parseArgument(canParsePositional);
      }
    }

    if (args.isEmpty && unit == null) {
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

  Argument parseArgument(bool canParsePositional) {
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
    } else if (canParsePositional) {
      var expr = parse();
      if (expr == null) return null;
      return new Argument(expr);
    } else {
      return null;
    }
  }

  void addPrefixParselets() {
    PrefixParselet<Expression> parseString(TokenType type) {
      return (p, token) {
        return p.parseString(token);
      };
    }

    addString(TokenType type) => addPrefix(type, parseString(type));
    addString(TokenType.doubleQuote);
    addString(TokenType.singleQuote);
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
    addPrefix(TokenType.await$, (p, token) {
      var expr = p.expressionParser.parse();
      if (expr != null) {
        return new AwaitedExpression([], token.span.expand(expr.span), expr);
      } else {
        p.exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            token.span, "Missing expression after 'await' keyword."));
        return null;
      }
    });
    addPrefix(TokenType.begin, (p, token) {
      var span = token.span, lastSpan = span;
      var letBindings = <LetBinding>[];
      var ignored = <Expression>[];

      var letBinding = p.functionParser.parseLetBinding();
      while (letBinding != null) {
        letBindings.add(letBinding);
        span = span.expand(lastSpan = letBinding.span);
        letBinding = p.functionParser.parseLetBinding();
      }

      Expression returnValue, value = p.expressionParser.parse();

      while (value != null) {
        span = span.expand(lastSpan = value.span);
        if (returnValue == null) {
          returnValue = value;
        } else {
          ignored.add(returnValue);
          returnValue = value;
        }

        if (p.peek()?.type != TokenType.semi || !p.moveNext()) {
          break;
        } else {
          span = span.expand(lastSpan = p.current.span);
          value = p.expressionParser.parse();
        }
      }

      if (returnValue == null) {
        p.exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            lastSpan, "This block has no return value."));
        returnValue = new NullLiteral([], token.span);
      }

      if (p.peek()?.type == TokenType.end && p.moveNext()) {
        span = span.expand(p.current.span);
      } else {
        p.exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            lastSpan, "Missing 'end' keyword at end of block."));
      }

      return new BeginEndExpression(
          [], span, letBindings, ignored, returnValue);
    });
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

    Expression member(Parser p, _, Expression left, Token token) {
      if (p.peek()?.type == TokenType.id && p.moveNext()) {
        var id = new Identifier([], p.current);
        return new MemberExpression(left.comments,
            left.span.expand(token.span).expand(id.span), left, id, token);
      } else {
        p.exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            token.span, "Missing identifier after '.'."));
        return null;
      }
    }

    addInfix(TokenType.times, arithmetic);
    addInfix(TokenType.div, arithmetic);
    addInfix(TokenType.mod, arithmetic);
    addInfix(TokenType.plus, arithmetic);
    addInfix(TokenType.minus, arithmetic);
    addInfix(TokenType.dot, member);
    addInfix(TokenType.nonNullDot, member);
    addInfix(TokenType.nullableDot, member);
  }
}
