import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';

class ExprParser {
  final Parser parser;

  ExprParser(this.parser);

  /// Parses a single expression, WITH checking for operators, calls, etc.
  /// If [allowDefinitions] is `false`, then the parser will not look for
  /// `let` or `fun`.
  ///
  /// [allowCalls] defaults to [allowDefinitions].
  ExprNode parseExpression({bool allowDefinitions = false, bool allowCalls}) {
    allowCalls ??= allowDefinitions;
    // TODO: Infix
    var left = parseUnaryExpression(allowDefinitions: allowDefinitions);

    if (!allowCalls || left == null) {
      return left;
    } else {
      var span = left.span, lastSpan = span;
      FileSpan argSpan;
      var requireNamed = false;
      var args = <ArgNode>[];
      var arg = parseArg(requireNamed, lastSpan);
      while (arg != null) {
        if (argSpan == null) {
          argSpan = arg.span;
        } else {
          argSpan = argSpan.expand(arg.span);
        }
        span = span.expand(lastSpan = arg.span);
        requireNamed = requireNamed || (arg.name != null);
        args.add(arg);
        arg = parseArg(requireNamed, lastSpan);
      }
      if (args.isEmpty) {
        return left;
      } else {
        var argList = ArgListNode(argSpan, args);
        return CallExprNode(span, left, argList);
      }
    }
  }

  /// Parses a single expression, WITHOUT checking for operators, calls, etc.
  /// If [allowDefinitions] is `false`, then the parser will not look for
  /// `let` or `fun`.
  ExprNode parseUnaryExpression({bool allowDefinitions = false}) {
    // Id
    if (parser.nextIs(TokenType.ID)) {
      return IdExprNode(parser.lastToken.span);
    }

    // IntLiteral
    else if (parser.nextIs(TokenType.HEX)) {
      return IntLiteralNode(
          parser.lastToken.span, int.parse(parser.lastToken.span.text));
    } else if (parser.nextIs(TokenType.INT)) {
      return IntLiteralNode(parser.lastToken.span,
          double.parse(parser.lastToken.span.text).toInt());
    }

    // DoubleLiteral
    else if (parser.nextIs(TokenType.DOUBLE)) {
      return DoubleLiteralNode(
          parser.lastToken.span, double.parse(parser.lastToken.span.text));
    }

    // VoidLiteral
    else if (parser.nextIs(TokenType.LPAREN)) {
      var span = parser.lastToken.span, lastSpan = span;
      var expr = parseExpression(allowDefinitions: true);
      if (expr != null) {
        span = span.expand(lastSpan = expr.span);
      }
      if (!parser.nextIs(TokenType.RPAREN)) {
        parser.emitError(lastSpan, 'Missing ")".');
        return null;
      } else {
        span = span.expand(parser.lastToken.span);
        if (expr == null) {
          return VoidLiteralNode(span);
        } else {
          return ParenExprNode(span, expr);
        }
      }
    }

    // StringLiteral
    else if (parser.nextIsAnyOf([
      TokenType.DOUBLE_QUOTE,
      TokenType.SINGLE_QUOTE,
      TokenType.TRIPLE_DOUBLE_QUOTE,
      TokenType.TRIPLE_SINGLE_QUOTE,
      TokenType.RAW_DOUBLE_QUOTE,
      TokenType.RAW_SINGLE_QUOTE,
      TokenType.RAW_TRIPLE_DOUBLE_QUOTE,
      TokenType.RAW_TRIPLE_SINGLE_QUOTE,
    ])) {
      var span = parser.lastToken.span, lastSpan = span;
      var parts = <StringPartNode>[];

      // Figure out what kind of token we expect to see at the end of the
      // string
      TokenType closingType;
      switch (parser.lastToken.type) {
        case TokenType.RAW_DOUBLE_QUOTE:
          closingType = TokenType.DOUBLE_QUOTE;
          break;
        case TokenType.RAW_SINGLE_QUOTE:
          closingType = TokenType.SINGLE_QUOTE;
          break;
        case TokenType.RAW_TRIPLE_DOUBLE_QUOTE:
          closingType = TokenType.TRIPLE_DOUBLE_QUOTE;
          break;
        case TokenType.RAW_TRIPLE_SINGLE_QUOTE:
          closingType = TokenType.TRIPLE_SINGLE_QUOTE;
          break;
        default:
          closingType = parser.lastToken.type;
          break;
      }

      var part = parseStringPart();
      while (part != null) {
        span = span.expand(lastSpan = part.span);
        parts.add(part);
        part = parseStringPart();
      }

      if (!parser.nextIs(closingType)) {
        parser.emitError(lastSpan, 'Unterminated string literal.');
        return null;
      } else {
        span = span.expand(parser.lastToken.span);
        return StringLiteralNode(span, parts);
      }
    }

    // Await
    else if (parser.nextIs(TokenType.AWAIT)) {
      var span = parser.lastToken.span;
      var target = parseExpression(allowCalls: true);
      if (target == null) {
        parser.emitError(span, 'Missing expression after "await".');
        return null;
      } else {
        span = span.expand(target.span);
        return AwaitExprNode(span, target);
      }
    }

    // THROW
    else if (parser.nextIs(TokenType.THROW)) {
      var span = parser.lastToken.span;
      var target = parseExpression(allowCalls: true);
      if (target == null) {
        parser.emitError(span, 'Missing expression after "throw".');
        return null;
      } else {
        span = span.expand(target.span);
        return ThrowExprNode(span, target);
      }
    }

    // BeginEnd
    else if (parser.nextIs(TokenType.BEGIN)) {
      var span = parser.lastToken.span, lastSpan = span;
      var body = <ExprNode>[];
      var expr = parseExpression(allowDefinitions: true);
      while (expr != null) {
        body.add(expr);
        span = span.expand(lastSpan = expr.span);
        expr = parseExpression(allowDefinitions: true);
      }
      if (!parser.nextIs(TokenType.END)) {
        parser.emitError(lastSpan, 'Missing "end".');
        return null;
      } else if (body.isEmpty) {
        parser.emitError(
            lastSpan, 'A "begin ... end" expression must have a body.');
        return null;
      } else {
        return BeginEndNode(span, body);
      }
    }

    // Catch-all
    else {
      return null;
    }
  }

  /// Parses an argument for a call.
  ArgNode parseArg(bool requireNamed, FileSpan lastSpan) {
    const expectNamed = 'Expected a named argument.';

    if (parser.nextIs(TokenType.ID)) {
      var name = IdExprNode(parser.lastToken.span),
          span = name.span,
          lastSpan = span;
      if (!parser.nextIs(TokenType.EQUALS)) {
        if (requireNamed) {
          parser.emitError(lastSpan, 'Missing "=" after identifier.');
          return null;
        } else {
          return ArgNode(name.span, null, name);
        }
      } else {
        span = span.expand(lastSpan = parser.lastToken.span);
        var value = parseExpression();
        if (value == null) {
          parser.emitError(lastSpan, 'Missing expression after "=".');
          return null;
        } else {
          return ArgNode(value.span, name, value);
        }
      }
    } else {
      var value = parseExpression();
      if (value == null) {
        return null;
      } else if (requireNamed) {
        parser.emitError(value.span, expectNamed);
        return null;
      } else {
        return ArgNode(value.span, null, value);
      }
    }
  }

  StringPartNode parseStringPart() {
    if (parser.nextIs(TokenType.ESCAPE_SEQUENCE)) {
      var value = '';
      switch (parser.lastToken.match[1]) {
        case 'b':
          value = '\b';
          break;
        case 'f':
          value = '\f';
          break;
        case 'n':
          value = '\n';
          break;
        case 'r':
          value = '\r';
          break;
        case 't':
          value = '\t';
          break;
        default:
          parser.emitError(parser.lastToken.span,
              'Unrecognized escape sequence. This is a bug in the compiler.');
          return null;
      }
      return TextStringPartNode(parser.lastToken.span, value);
    } else if (parser.nextIs(TokenType.ESCAPE_DOLLAR)) {
      return TextStringPartNode(parser.lastToken.span, '\$');
    } else if (parser
        .nextIsAnyOf([TokenType.ESCAPE_HEX, TokenType.ESCAPE_UNICODE])) {
      var value = int.parse(parser.lastToken.match[1], radix: 16);
      return TextStringPartNode(
          parser.lastToken.span, String.fromCharCode(value));
    } else if (parser.nextIs(TokenType.ESCAPE_DOUBLE_QUOTE)) {
      return TextStringPartNode(parser.lastToken.span, '"');
    } else if (parser.nextIs(TokenType.ESCAPE_SINGLE_QUOTE)) {
      return TextStringPartNode(parser.lastToken.span, "'");
    } else if (parser.nextIs(TokenType.ESCAPE_TRIPLE_DOUBLE_QUOTE)) {
      return TextStringPartNode(parser.lastToken.span, '"""');
    } else if (parser.nextIs(TokenType.ESCAPE_TRIPLE_SINGLE_QUOTE)) {
      return TextStringPartNode(parser.lastToken.span, "'''");
    } else if (parser.nextIs(TokenType.TEXT)) {
      return TextStringPartNode(
          parser.lastToken.span, parser.lastToken.span.text);
    }

    // Manufacture an IdExprNode here
    else if (parser.nextIs(TokenType.ESCAPED_ID)) {
      return InterpolationStringPartNode(
        parser.lastToken.span,
        IdExprNode(parser.lastToken.span, parser.lastToken.match[1]),
      );
    }

    // Search for an expr
    else if (parser.nextIs(TokenType.DOLLAR_LCURLY)) {
      var span = parser.lastToken.span, lastSpan = span;
      var expr = parseExpression(allowDefinitions: true);
      if (expr == null) {
        parser.emitError(lastSpan, 'Missing expression after "\${".');
        return null;
      } else {
        span = span.expand(lastSpan = expr.span);
        if (!parser.nextIs(TokenType.RCURLY)) {
          parser.emitError(lastSpan, '"}".');
          return null;
        } else {
          span = span.expand(parser.lastToken.span);
          return InterpolationStringPartNode(span, expr);
        }
      }
    } else {
      return null;
    }
  }
}
