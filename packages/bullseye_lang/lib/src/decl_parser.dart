import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';

class DeclParser {
  final Parser parser;

  DeclParser(this.parser);

  ParamListNode parseParamList(FileSpan lastSpan) {
    var span = lastSpan;
    var params = <ParamNode>[];
    var param = parseParam(false);
    var requireNamed = false;
    while (param != null) {
      span = span.expand(lastSpan = param.span);
      params.add(param);
      requireNamed = requireNamed || param.defaultValue != null;
      param = parseParam(requireNamed);
    }
    return ParamListNode(span, params);
  }

  ParamNode parseParam(bool requireNamed) {
    var pattern = parser.patternParser.parsePattern();
    if (pattern == null) {
      return null;
    }

    var span = pattern.span, lastSpan = span;
    if (!parser.nextIs(TokenType.EQUALS)) {
      if (!requireNamed) {
        return ParamNode(span, pattern, null);
      } else {
        parser.emitError(lastSpan, 'Expected a named parameter.');
        return null;
      }
    }

    if (pattern is! IdPatternNode) {
      parser.emitError(
          lastSpan, '"=" must be preceded by an identifier pattern.');
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
