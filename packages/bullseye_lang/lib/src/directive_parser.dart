import 'package:bullseye_lang/bullseye_lang.dart';

class DirectiveParser {
  final Parser parser;

  DirectiveParser(this.parser);

  DirectiveNode parseDirective() {
    if (!parser.nextIsAnyOf([TokenType.IMPORT, TokenType.EXPORT])) {
      return null;
    } else {
      var span = parser.lastToken.span, lastSpan = span;
      var isExport = parser.lastToken.type == TokenType.EXPORT;

      var expr = parser.exprParser.parseExpression();
      if (expr != null) {
        lastSpan = parser.lastToken.span;
      }

      if (expr == null || expr is! StringLiteralNode) {
        parser.emitError(lastSpan,
            'Expected string after "${isExport ? 'export' : 'import'}"');
        return null;
      }

      var path = expr as StringLiteralNode;
      span = span.expand(lastSpan = path.span);

      var modifiers = <ImportModifierNode>[];
      var modifier = parseImportModifier();
      while (modifier != null) {
        span = span.expand(lastSpan = modifier.span);
        modifiers.add(modifier);
        modifier = parseImportModifier();
      }

      return ImportDirectiveNode(span, isExport, path, modifiers);
    }
  }

  ImportModifierNode parseImportModifier() {
    if (!parser.nextIsAnyOf([TokenType.SHOW, TokenType.HIDE])) {
      return null;
    } else {
      var span = parser.lastToken.span, lastSpan = span;
      var isHide = parser.lastToken.type == TokenType.HIDE;
      var names = <IdExprNode>[];
      while (parser.nextIs(TokenType.ID)) {
        var name = IdExprNode(parser.lastToken.span);
        span = span.expand(lastSpan = name.span);
        names.add(name);
        if (!parser.nextIs(TokenType.COMMA)) {
          break;
        }
      }

      if (names.isEmpty) {
        parser.emitError(lastSpan,
            'Missing identifier after "${isHide ? 'hide' : 'show'}".');
        return null;
      }

      return ImportModifierNode(span, isHide, names);
    }
  }
}
