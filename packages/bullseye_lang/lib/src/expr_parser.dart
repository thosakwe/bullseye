import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';

class ExprParser {
  final Parser parser;

  ExprParser(this.parser);

  /// Parses an argument for a call.
  ArgNode parseArg(bool requireNamed, FileSpan lastSpan) {
    const expectNamed = 'Expected a named argument.';

    if (parser.nextIs(TokenType.ID)) {
      var name = IdNode(parser.lastToken.span),
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
      return IdNode(parser.lastToken.span);
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
}
