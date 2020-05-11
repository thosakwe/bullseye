import 'package:bullseye_lang/bullseye_lang.dart';

class PatternParser {
  final Parser parser;

  PatternParser(this.parser);

  PatternNode parsePattern() {
    var pattern = parseUnaryPattern();
    if (pattern == null) {
      return null;
    } else if (parser.nextIs(TokenType.AS)) {
      var lastSpan = parser.lastToken.span;
      var span = pattern.span.expand(lastSpan);
      if (!parser.nextIs(TokenType.ID)) {
        parser.emitError(lastSpan, 'Missing identifier after "as".');
        return null;
      } else {
        var id = IdExprNode(parser.lastToken.span);
        span = span.expand(id.span);
        return AliasedPatternNode(span, pattern, id);
      }
    } else {
      return pattern;
    }
  }

  PatternNode parseUnaryPattern() {
    if (parser.nextIs(TokenType.ID)) {
      if (parser.lastToken.span.text == '_') {
        return IgnoredPatternNode(parser.lastToken.span);
      } else {
        var id = IdExprNode(parser.lastToken.span);
        return IdPatternNode(id.span, id);
      }
    } else if (parser.nextIs(TokenType.LPAREN)) {
      var span = parser.lastToken.span, lastSpan = span;
      var inner = parsePattern();
      if (inner != null) {
        span = span.expand(lastSpan = inner.span);
      }
      if (!parser.nextIs(TokenType.RPAREN)) {
        parser.emitError(lastSpan, 'Missing ")".');
        return null;
      } else {
        span = span.expand(parser.lastToken.span);
        if (inner != null) {
          return ParenPatternNode(span, inner);
        } else {
          return VoidPatternNode(span);
        }
      }
    } else {
      var expr = parser.exprParser.parseExpression();
      if (expr == null) {
        return null;
      } else {
        return ExprPatternNode(expr.span, expr);
      }
    }
  }
}
