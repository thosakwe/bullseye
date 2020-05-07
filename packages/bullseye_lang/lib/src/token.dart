import 'package:source_span/source_span.dart';

class Token {
  final FileSpan span;
  final TokenType type;
  final Object value;

  Token(this.span, this.type, [this.value]);
}

enum TokenType {
  COMMENT,

  // Misc. symbols
  ARROBA,
  ARROW,
  COMMA,
  LCURLY,
  RCURLY,
  LBRACKET,
  RBRACKET,
  LPAREN,
  RPAREN,
  SEMI,

  // Operators
  COLON_EQUALS,
  DOT,
  ELLIPSIS,
  EQUALS,

  // Keywords
  ASYNC,
  AWAIT,
  CATCH,
  FUN,
  IN,
  LET,
  MATCH,
  OPEN,
  TRY,
  WITH,

  // Values
  DOUBLE,
  INT,
  ID,
}
