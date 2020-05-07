import 'package:source_span/source_span.dart';

class Token {
  final FileSpan span;
  final TokenType type;
  final Match match;
  final Object value;

  Token(this.span, this.type, this.match, [this.value]);

  @override
  String toString() => '${span.start.toolString} => $type';
}

enum TokenType {
  COMMENT,

  // Misc. symbols
  ARROBA,
  ARROW,
  COLON,
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
  LT,
  LTE,
  GT,
  GTE,
  AND,
  OR,
  XOR,
  BOOL_AND,
  BOOL_OR,
  BOOL_EQUALS,
  BOOL_NEQ,
  NOT,

  // Keywords
  ABSTRACT,
  ASYNC,
  AWAIT,
  CATCH,
  CLASS,
  EXTENDS,
  FUN,
  IMPLEMENTS,
  IN,
  LET,
  MATCH,
  OF,
  OPEN,
  TRY,
  TYPE,
  WITH,

  // Values
  DOUBLE,
  HEX,
  INT,
  ID,

  // String parts
  DOUBLE_QUOTE,
  SINGLE_QUOTE,
  TRIPLE_DOUBLE_QUOTE,
  TRIPLE_SINGLE_QUOTE,
  ESCAPED_ID,
  ESCAPE_SEQUENCE,
  ESCAPE_DOLLAR,
  ESCAPE_HEX,
  ESCAPE_UNICODE,
  ESCAPE_DOUBLE_QUOTE,
  ESCAPE_SINGLE_QUOTE,
  ESCAPE_TRIPLE_DOUBLE_QUOTE,
  ESCAPE_TRIPLE_SINGLE_QUOTE,
  DOLLAR_LCURLY,
  TEXT,
}
