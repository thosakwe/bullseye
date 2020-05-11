import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';

class DeclParser {
  final Parser parser;

  DeclParser(this.parser);

  DeclNode parseDecl() {
    if (parser.nextIs(TokenType.LET)) {
      var span = parser.lastToken.span, lastSpan = span;
      if (!parser.nextIs(TokenType.ID)) {
        parser.emitError(lastSpan, 'Missing identifier after "let".');
        return null;
      }

      var name = IdExprNode(parser.lastToken.span);
      span = span.expand(lastSpan = name.span);

      var paramList = parser.declParser.parseParamList(lastSpan);
      span = span.expand(lastSpan = paramList.span);
      if (!parser.nextIs(TokenType.EQUALS)) {
        parser.emitError(parser.lastToken.span, 'Missing "=".');
        return null;
      }

      span = span.expand(lastSpan = parser.lastToken.span);
      var value = parser.exprParser.parseExpression(allowDefinitions: true);
      if (value == null) {
        parser.emitError(lastSpan, 'Missing expression after "=".');
        return null;
      }

      return LetDeclNode(span, name, paramList, value);
    }
    if (parser.nextIs(TokenType.TYPE)) {
      var span = parser.lastToken.span, lastSpan = span;
      if (!parser.nextIs(TokenType.ID)) {
        parser.emitError(lastSpan, 'Missing identifier after "type".');
        return null;
      }

      var name = IdExprNode(parser.lastToken.span);
      span = span.expand(lastSpan = name.span);

      var params = <IdExprNode>[];
      while (parser.nextIs(TokenType.ID)) {
        var id = IdExprNode(parser.lastToken.span);
        span = span.expand(lastSpan = id.span);
        params.add(id);
      }

      if (!parser.nextIs(TokenType.EQUALS)) {
        parser.emitError(lastSpan, 'Missing "=".');
        return null;
      }

      span = span.expand(lastSpan = parser.lastToken.span);
      var type = parser.typeParser.parseType();
      if (type == null) {
        parser.emitError(lastSpan, 'Missing type after "=".');
        return null;
      }

      return TypeDeclNode(span, name, params, type);
    } else {
      return null;
    }
  }

  ParamListNode parseParamList(FileSpan lastSpan) {
    var span = lastSpan;
    var params = <ParamNode>[];
    var param = parseParam(false, lastSpan);
    var requireNamed = false;
    while (param != null) {
      span = span.expand(lastSpan = param.span);
      params.add(param);
      requireNamed = requireNamed || param.defaultValue != null;
      param = parseParam(requireNamed, lastSpan);
    }
    return ParamListNode(span, params);
  }

  ParamNode parseParam(bool requireNamed, FileSpan lastSpan) {
    if (!parser.nextIs(TokenType.TILDE)) {
      if (requireNamed) {
        // parser.emitError(lastSpan, 'Expected a named parameter.');
        return null;
      } else {
        var pattern = parser.patternParser.parsePattern();
        if (pattern == null) {
          return null;
        } else {
          return ParamNode(pattern.span, pattern, null);
        }
      }
    }

    var span = parser.lastToken.span;
    lastSpan = span;

    if (!parser.nextIs(TokenType.ID)) {
      parser.emitError(lastSpan, 'Missing identifier after "~".');
      return null;
    }

    var id = IdExprNode(parser.lastToken.span);
    var pattern = IdPatternNode(span, id);
    span = span.expand(lastSpan = id.span);

    span = span.expand(lastSpan = pattern.span);

    if (!parser.nextIs(TokenType.EQUALS)) {
      parser.emitError(lastSpan, 'Expected "=" after identifier.');
      return null;
    }

    span = span.expand(lastSpan = parser.lastToken.span);
    var defaultValue = parser.exprParser.parseExpression();
    if (defaultValue == null) {
      parser.emitError(lastSpan, 'Expected an expression after "=".');
      return null;
    } else {
      span = span.expand(defaultValue.span);
      return ParamNode(span, pattern, defaultValue);
    }
  }
}
