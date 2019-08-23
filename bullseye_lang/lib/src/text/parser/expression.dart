import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';

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
        var e = arg.expression;
        // Attempt to fold in a smaller call
        if (e is CallExpression) {
          args.add(Argument(e.callee));
          args.addAll(e.arguments);
          canParsePositional =
              canParsePositional && !e.arguments.any((a) => a is NamedArgument);
        } else {
          canParsePositional = canParsePositional && arg is! NamedArgument;
          args.add(arg);
        }

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
    if (parser.peek()?.type == TokenType.bitwiseNegate && parser.moveNext()) {
      var tilde = parser.current;

      if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
        var id = Identifier([], parser.current);

        if (parser.peek()?.type == TokenType.colon && parser.moveNext()) {
          var colon = parser.current;
          var expr = parse();
          if (expr != null) {
            return new NamedArgument([],
                tilde.span.expand(id.span).expand(colon.span).expand(expr.span),
                id,
                expr);
          } else {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                colon.span,
                "Missing expression after ':' for named argument '${id.name}'."));
            return null;
          }
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              id.span,
              "Missing ':' in named argument '${id.name}'."));
          return null;
        }
      } else {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            tilde.span,
            "Missing identifier after '~' is named argument."));
        return null;
      }
    } else {
      var expr = parse();
      if (expr == null) return null;

      if (canParsePositional) {
        return new Argument(expr);
      } else {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            expr.span,
            "Positional arguments cannot follow named arguments."));
        return null;
      }
    }
  }

  FunctionExpression parseFunctionExpression([Token fun]) {
    if (fun == null) {
      if (parser.peek()?.type == TokenType.fun && parser.moveNext()) {
        fun = parser.current;
      } else {
        return null;
      }
    }

    var span = fun.span, lastSpan = span;
    var params = <FunctionExpressionParameter>[];
    var unit = parser.parseUnit();

    if (unit != null) {
      span = span.expand(lastSpan = unit.span);
    } else {
      var param = parseFunctionExpressionParameter();
      while (param != null) {
        params.add(param);
        span = span.expand(lastSpan = param.span);
        param = parseFunctionExpressionParameter();
      }

      if (params.isEmpty) {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            lastSpan,
            "Missing parameter list in anonymous function. If you intend to take zero parameters, use a unit ('()') literal."));
      }
    }

    var asyncMarker = parser.parseAsyncMarker();

    if (parser.peek()?.type == TokenType.arrow && parser.moveNext()) {
      var arrow = parser.current;
      span = span.expand(lastSpan = arrow.span);
    } else {
      parser.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          lastSpan,
          "Missing '=>' in anonymous function."));
    }

    var body = parser.expressionParser.parse();

    if (body == null) {
      parser.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          lastSpan,
          "Missing return value in anonymous function."));
      body = new NullLiteral([], fun.span);
    } else {
      span = span.expand(body.span);
    }

    return new FunctionExpression([], span, params, asyncMarker, body);
  }

  FunctionExpressionParameter parseFunctionExpressionParameter() {
    // TODO: Annotations
    // TODO: default values
    var annotations = <Annotation>[];

    if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
      var name = new Identifier([], parser.current);

      if (parser.peek()?.type == TokenType.colon && parser.moveNext()) {
        var colon = parser.current;
        var type = parser.typeParser.parse();

        if (type != null) {
          var span = name.span.expand(colon.span).expand(type.span);
          return new FunctionExpressionParameter(
              annotations, [], span, name, type);
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              colon.span,
              "Missing type after ':'."));
          return null;
        }
      } else {
        return new FunctionExpressionParameter(
            annotations, [], name.span, name, null);
      }
    } else {
      return null;
    }
  }

  RecordKVPair parseRecordKVPair() {
    if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
      var id = Identifier([], parser.current);

      if (parser.peek()?.type == TokenType.equals && parser.moveNext()) {
        var equals = parser.current;
        var value = parser.expressionParser.parse();

        if (value != null) {
          return RecordKVPair(
              [], id.span.expand(equals.span).expand(value.span), id, value);
        } else {
          parser.exceptions.add(BullseyeException(
              BullseyeExceptionSeverity.error,
              equals.span,
              "Missing expression after '=' in field '${id.name}'."));
          return null;
        }
      } else {
        return RecordKVPair([], id.span, id, id);
      }
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
    addPrefix(TokenType.fun,
        (p, token) => p.expressionParser.parseFunctionExpression(token));
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
      var letBindings = <LetInExpression>[];
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

    addPrefix(TokenType.lCurly, (p, token) {
      Expression withBinding;
      FileSpan span = token.span, lastSpan = span;

      withBinding = p.expressionParser.parse();

      if (withBinding != null) {
        span = span.expand(lastSpan = withBinding.span);

        if (parser.peek()?.type == TokenType.with$ && parser.moveNext()) {
          span = span.expand(parser.current.span);
        } else if (withBinding is Identifier) {
          // ID's take up just one token, so backtrack.
          withBinding = null;
          parser.movePrevious();
        } else {
          parser.exceptions.add(BullseyeException(
              BullseyeExceptionSeverity.error,
              lastSpan,
              "Missing 'with' keyword after expression."));
          return null;
        }
      }

      var pairs = <RecordKVPair>[];
      var pair = parseRecordKVPair();

      while (pair != null) {
        pairs.add(pair);
        span = span.expand(lastSpan = pair.span);

        if (parser.peek()?.type == TokenType.semi && parser.moveNext()) {
          pair = parseRecordKVPair();
          span = span.expand(parser.current.span);
        } else {
          break;
        }
      }

      if (parser.peek()?.type != TokenType.rCurly || !parser.moveNext()) {
        parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
            lastSpan, "Missing '}' in record expression literal."));
      } else {
        span = span.expand(parser.current.span);
      }

      if (pairs.isEmpty) {
        parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
            span, 'Record literals cannot be empty.'));
      }

      return RecordExpression([], span, withBinding, pairs);
    });

    // THIS MUST BE LAST.
    addPrefix(
      TokenType.id,
      (p, token) => new Identifier([], token),
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
