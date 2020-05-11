import 'package:bullseye_lang/bullseye_lang.dart';

class TypeParser {
  final Parser parser;

  TypeParser(this.parser);

  TypeNode parseType() {
    // TODO: Infix
    return parseUnaryType();
  }

  TypeNode parseUnaryType() {
    if (parser.nextIs(TokenType.ID)) {
      var id = IdExprNode(parser.lastToken.span);
      return TypeRefNode(id.span, id);
    } else {
      return null;
    }
  }
}
