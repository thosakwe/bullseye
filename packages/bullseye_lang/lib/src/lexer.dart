import 'dart:collection';
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:collection/collection.dart';
import 'package:string_scanner/string_scanner.dart';

enum LexerState {
  normal,
  doubleQuote,
  singleQuote,
  rawDoubleQuote,
  rawSingleQuote,
  tripleDoubleQuote,
  tripleSingleQuote,
  rawTripleDoubleQuote,
  rawTripleSingleQuote,
}

class Lexer {
  final SpanScanner scanner;
  var errors = <BullseyeError>[];

  Lexer(this.scanner);

  static final RegExp whiteSpace = RegExp(r'[ \n\r\t]+');

  static final Map<Pattern, TokenType> normalPatterns = {
    RegExp(r'--[^\n]*'): TokenType.COMMENT,

    // Misc. symbols
    '@': TokenType.ARROBA,
    '->': TokenType.ARROW,
    ':': TokenType.COLON,
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
    '<': TokenType.LT,
    '<=': TokenType.LTE,
    '>': TokenType.GT,
    '>=': TokenType.GTE,
    '&': TokenType.AND,
    '|': TokenType.OR,
    '^': TokenType.XOR,
    '&&': TokenType.BOOL_AND,
    '||': TokenType.BOOL_OR,
    '==': TokenType.BOOL_EQUALS,
    '!=': TokenType.BOOL_NEQ,
    '!': TokenType.NOT,
    '*': TokenType.TIMES,
    '/': TokenType.DIV,
    '%': TokenType.MOD,
    '+': TokenType.PLUS,
    '-': TokenType.MINUS,

    // Keywords
    'abstract': TokenType.ABSTRACT,
    'async': TokenType.ASYNC,
    'await': TokenType.AWAIT,
    'begin': TokenType.BEGIN,
    'catch': TokenType.CATCH,
    'class': TokenType.CLASS,
    'end': TokenType.END,
    'extends': TokenType.EXTENDS,
    'fun': TokenType.FUN,
    'implements': TokenType.IMPLEMENTS,
    'in': TokenType.IN,
    'let': TokenType.LET,
    'match': TokenType.MATCH,
    'of': TokenType.OF,
    'open': TokenType.OPEN,
    'throw': TokenType.THROW,
    'try': TokenType.TRY,
    'type': TokenType.TYPE,
    'with': TokenType.WITH,

    // Values
    RegExp(r'[-+]?[0-9]+(\.[0-9]+)?([Ee][-+]?[0-9]+)?'): TokenType.DOUBLE,
    RegExp(r'[-+]?0[Xx]([A-Fa-f0-9]+)'): TokenType.HEX,
    RegExp(r'[-+]?[0-9]+([Ee][-+]?[0-9]+)?'): TokenType.INT,
    RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*'): TokenType.ID,

    // String delimiters
    '"': TokenType.DOUBLE_QUOTE,
    "'": TokenType.SINGLE_QUOTE,
    'r"': TokenType.RAW_DOUBLE_QUOTE,
    "r'": TokenType.RAW_SINGLE_QUOTE,
    '"""': TokenType.TRIPLE_DOUBLE_QUOTE,
    "'''": TokenType.TRIPLE_SINGLE_QUOTE,
    'r"""': TokenType.RAW_TRIPLE_DOUBLE_QUOTE,
    "r'''": TokenType.RAW_TRIPLE_SINGLE_QUOTE,
  };

  static final Map<Pattern, TokenType> escapePatterns = {
    RegExp(r'\$[A-Za-z_$][A-Za-z0-9_$]*'): TokenType.ESCAPED_ID,
    RegExp(r'\\[bfnrt]'): TokenType.ESCAPE_SEQUENCE,
    RegExp(r'\\x([A-Fa-f0-9][A-Fa-f0-9])'): TokenType.ESCAPE_HEX,
    RegExp(r'\\u{([A-Fa-f0-9]+)}'): TokenType.ESCAPE_UNICODE,
    '\\\$': TokenType.ESCAPE_DOLLAR,
  };

  static final Map<Pattern, TokenType> genericStringPatterns =
      Map.of(escapePatterns)
        ..addAll({
          '\${': TokenType.DOLLAR_LCURLY,
        });

  static final Map<Pattern, TokenType> doubleQuotePatterns =
      Map.of(genericStringPatterns)
        ..addAll({
          '\\"': TokenType.ESCAPE_DOUBLE_QUOTE,
          '"': TokenType.DOUBLE_QUOTE,
          RegExp(r'[^"$]+'): TokenType.TEXT,
        });

  static final Map<Pattern, TokenType> singleQuotePatterns =
      Map.of(genericStringPatterns)
        ..addAll({
          "\\'": TokenType.ESCAPE_SINGLE_QUOTE,
          "'": TokenType.SINGLE_QUOTE,
          RegExp(r"[^'$]+"): TokenType.TEXT,
        });

  static final Map<Pattern, TokenType> rawDoubleQuotePatterns = {
    '\\"': TokenType.ESCAPE_DOUBLE_QUOTE,
    '"': TokenType.DOUBLE_QUOTE,
    RegExp(r'[^"]+'): TokenType.TEXT,
  };

  static final Map<Pattern, TokenType> rawSingleQuotePatterns = {
    "\\'": TokenType.ESCAPE_SINGLE_QUOTE,
    "'": TokenType.SINGLE_QUOTE,
    RegExp(r"[^']+"): TokenType.TEXT,
  };

  static final Map<Pattern, TokenType> tripleDoubleQuotePatterns =
      Map.of(genericStringPatterns)
        ..addAll({
          '\\"""': TokenType.ESCAPE_TRIPLE_DOUBLE_QUOTE,
          '"""': TokenType.TRIPLE_DOUBLE_QUOTE,
          RegExp(r"[^'$]+"): TokenType.TEXT,
        });

  static final Map<Pattern, TokenType> tripleSingleQuotePatterns =
      Map.of(genericStringPatterns)
        ..addAll({
          "\\'''": TokenType.ESCAPE_TRIPLE_SINGLE_QUOTE,
          "'''": TokenType.TRIPLE_SINGLE_QUOTE,
          RegExp(r"[^'$]+"): TokenType.TEXT,
        });

  static final Map<Pattern, TokenType> rawTripleDoubleQuotePatterns = {
    '\\"""': TokenType.ESCAPE_TRIPLE_DOUBLE_QUOTE,
    '"""': TokenType.TRIPLE_DOUBLE_QUOTE,
    '""': TokenType.TEXT,
    '"': TokenType.TEXT,
    RegExp(r'[^"]+'): TokenType.TEXT,
  };

  static final Map<Pattern, TokenType> rawTripleSingleQuotePatterns = {
    "\\'''": TokenType.ESCAPE_TRIPLE_SINGLE_QUOTE,
    "'''": TokenType.TRIPLE_SINGLE_QUOTE,
    "''": TokenType.TEXT,
    "'": TokenType.TEXT,
    RegExp(r"[^']+"): TokenType.TEXT,
  };

  Iterable<Token> produceTokens() sync* {
    var states = Queue<LexerState>()..addFirst(LexerState.normal);
    LineScannerState errorStart;

    void flush() {
      if (errorStart != null) {
        var span = scanner.spanFrom(errorStart);
        var message = 'Unexpected text "${span.text}".';
        errors.add(BullseyeError(span, BullseyeErrorSeverity.error, message));
        errorStart = null;
      }
    }

    while (!scanner.isDone) {
      var tokens = <Token>[];
      if (states.first == LexerState.normal && scanner.scan(whiteSpace)) {
        continue;
      } else {
        Map<Pattern, TokenType> patterns;
        TokenType sentinel;
        String tripleQuote;
        var lookForTripleQuote = false;

        switch (states.first) {
          case LexerState.normal:
            patterns = normalPatterns;
            sentinel = TokenType.RCURLY;
            break;
          case LexerState.doubleQuote:
            patterns = doubleQuotePatterns;
            sentinel = TokenType.DOUBLE_QUOTE;
            break;
          case LexerState.singleQuote:
            patterns = singleQuotePatterns;
            sentinel = TokenType.SINGLE_QUOTE;
            break;
          case LexerState.rawDoubleQuote:
            patterns = rawDoubleQuotePatterns;
            sentinel = TokenType.DOUBLE_QUOTE;
            break;
          case LexerState.rawSingleQuote:
            patterns = rawSingleQuotePatterns;
            sentinel = TokenType.SINGLE_QUOTE;
            break;
          case LexerState.tripleDoubleQuote:
            patterns = tripleDoubleQuotePatterns;
            sentinel = TokenType.TRIPLE_DOUBLE_QUOTE;
            lookForTripleQuote = true;
            tripleQuote = '"""';
            break;
          case LexerState.tripleSingleQuote:
            patterns = tripleSingleQuotePatterns;
            sentinel = TokenType.TRIPLE_SINGLE_QUOTE;
            lookForTripleQuote = true;
            tripleQuote = "'''";
            break;
          case LexerState.rawTripleDoubleQuote:
            patterns = rawTripleDoubleQuotePatterns;
            sentinel = TokenType.TRIPLE_DOUBLE_QUOTE;
            lookForTripleQuote = true;
            tripleQuote = '"""';
            break;
          case LexerState.rawTripleSingleQuote:
            patterns = rawTripleSingleQuotePatterns;
            sentinel = TokenType.TRIPLE_SINGLE_QUOTE;
            lookForTripleQuote = true;
            tripleQuote = '"""';
            break;
        }

        patterns.forEach((pattern, type) {
          if (scanner.matches(pattern)) {
            if (lookForTripleQuote &&
                scanner.lastSpan.text.startsWith(tripleQuote) &&
                type != sentinel) {
              return;
            }
            tokens.add(Token(scanner.lastSpan, type, scanner.lastMatch));
          }
        });

        if (tokens.isEmpty) {
          errorStart ??= scanner.state;
          scanner.readChar();
        } else {
          flush();
          mergeSort<Token>(tokens,
              compare: (a, b) => b.span.length.compareTo(a.span.length));
          scanner.position += tokens.first.span.length;
          yield tokens.first;

          if (tokens.first.type == sentinel) {
            states.removeFirst();
          } else {
            switch (states.first) {
              case LexerState.normal:
                switch (tokens.first.type) {
                  case TokenType.LCURLY:
                    states.addFirst(LexerState.normal);
                    break;
                  case TokenType.DOUBLE_QUOTE:
                    states.addFirst(LexerState.doubleQuote);
                    break;
                  case TokenType.SINGLE_QUOTE:
                    states.addFirst(LexerState.singleQuote);
                    break;
                  case TokenType.RAW_DOUBLE_QUOTE:
                    states.addFirst(LexerState.rawDoubleQuote);
                    break;
                  case TokenType.RAW_SINGLE_QUOTE:
                    states.addFirst(LexerState.rawSingleQuote);
                    break;
                  case TokenType.TRIPLE_DOUBLE_QUOTE:
                    states.addFirst(LexerState.tripleDoubleQuote);
                    break;
                  case TokenType.TRIPLE_SINGLE_QUOTE:
                    states.addFirst(LexerState.tripleSingleQuote);
                    break;
                  case TokenType.RAW_TRIPLE_DOUBLE_QUOTE:
                    states.addFirst(LexerState.rawTripleDoubleQuote);
                    break;
                  case TokenType.RAW_TRIPLE_SINGLE_QUOTE:
                    states.addFirst(LexerState.rawTripleSingleQuote);
                    break;
                  default:
                    break;
                }
                break;
              default:
                if (tokens.first.type == TokenType.DOLLAR_LCURLY) {
                  states.addFirst(LexerState.normal);
                }
                break;
            }
          }
        }
      }
    }
    flush();
  }
}
