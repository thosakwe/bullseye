import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:string_scanner/string_scanner.dart';

class Lexer {
  final SpanScanner scanner;

  Lexer(this.scanner);

  static final RegExp whiteSpace = RegExp(r'[ \n\r\t]+');

  static final Map<Pattern, TokenType> patterns = {
    RegExp(r'--[^\n]*'): TokenType.COMMENT,

    // Misc. symbols
    '@': TokenType.ARROBA,
    '->': TokenType.ARROW,
    ',': TokenType.COMMA,
    '{': TokenType.LCURLY,
    '}': TokenType.RCURLY,
    '[': TokenType.LBRACKET,
    ']': TokenType.RBRACKET,
    '(': TokenType.LPAREN,
    ')': TokenType.RPAREN,
    ';': TokenType.SEMI,

    // Operators
    ':=': TokenType.COLON_EQUALS,
    '.': TokenType.DOT,
    '...': TokenType.ELLIPSIS,
    '=': TokenType.EQUALS,

    // Keywords
    'async': TokenType.ASYNC,
    'await': TokenType.AWAIT,
    'catch': TokenType.CATCH,
    'fun': TokenType.FUN,
    'in': TokenType.IN,
    'let': TokenType.LET,
    'match': TokenType.MATCH,
    'open': TokenType.OPEN,
    'try': TokenType.TRY,
    'with': TokenType.WITH,

    // Values
    RegExp(r'[-+]?[0-9]+(\.[0-9]+)?([Ee][-+]?[0-9]+)?'): TokenType.DOUBLE,
    RegExp(r'[-+]?[0-9]+([Ee][-+]?[0-9]+)?'): TokenType.INT,
    RegExp(r'[A-Za-z_][A-Za-z0-9_]*'): TokenType.ID,
  };

  Iterable<Token> produceTokens() sync* {
    LineScannerState errorStart;

    void flush() {
      // TODO: Keep track of syntax errors.
    }

    while (!scanner.isDone) {
      var tokens = <Token>[];
      if (scanner.scan(whiteSpace)) {
        continue;
      } else {
        patterns.forEach((pattern, type) {
          if (scanner.matches(pattern)) {
            tokens.add(Token(scanner.lastSpan, type));
          }
        });

        if (tokens.isEmpty) {
          // TODO: Syntax errors
          scanner.readChar();
        } else {
          flush();
          tokens.sort((b, a) => b.span.length.compareTo(a.span.length));
          scanner.position += tokens.first.span.length;
          yield tokens.first;
        }
      }
    }
    flush();
  }
}
