import 'dart:collection';
import 'package:string_scanner/string_scanner.dart';
import 'exception.dart';
import 'token.dart';
import 'token_type.dart';

class ScannerIterator extends BidirectionalIterator<Token> {
  final Scanner scanner;
  Token _current;
  int _index = -1;

  ScannerIterator(this.scanner);

  void reset() => _index = -1;

  @override
  Token get current => _current;

  bool get done {
    if (_index < scanner.tokens.length - 1) {
      return false;
    } else {
      return true;
    }
  }

  Token peek() {
    if (!done) {
      return scanner.tokens[_index + 1];
    } else {
      return null;
    }
  }

  @override
  bool moveNext() {
    if (done) {
      return false;
    } else {
      _index++;
      _current = scanner.tokens[_index];
      return true;
    }
  }

  @override
  bool movePrevious() {
    if (_index >= 0) {
      _index--;
      return true;
    } else {
      return false;
    }
  }
}

class Scanner extends Iterable<Token> with IterableMixin<Token> {
  final SpanScanner scanner;
  final List<BullseyeException> exceptions = [];
  final List<Token> tokens = [];
  final Queue<SubScannerBase> stateStack = new Queue<SubScannerBase>();
  LineScannerState _errantState;

  Scanner(this.scanner) {
    stateStack.addFirst(new NormalModeScanner(this));
  }

  ScannerIterator get iterator => new ScannerIterator(this);

  void scan() {
    while (!scanner.isDone && stateStack.isNotEmpty) {
      stateStack.first.scan();
    }

    flush();
  }

  void markErrant() {
    _errantState ??= scanner.state;
  }

  void flush() {
    if (_errantState != null) {
      var span = scanner.spanFrom(_errantState);
      exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
          span, 'Unexpected text "${span.text}".'));
    }

    _errantState = null;
  }
}

enum ScannerState { normal, string }

abstract class SubScannerBase {
  Map<Pattern, TokenType> get patterns;

  Scanner get scanner;

  Token scan() {
    var maybe = <Token>[];
    var s = scanner.scanner;

    patterns.forEach((pattern, type) {
      if (s.matches(pattern)) {
        maybe.add(new Token(type, s.lastSpan, s.lastMatch));
      }
    });

    if (maybe.isEmpty) {
      scanner.markErrant();
      s.readChar();
      return null;
    } else {
      scanner.flush();
      maybe.sort((a, b) => b.span.text.length.compareTo(a.span.text.length));
      var token = maybe.first;
      s.scan(token.span.text);
      scanner.tokens.add(token);
      return token;
    }
  }
}

class NormalModeScanner extends SubScannerBase {
  static final RegExp whitespace = new RegExp(r'[ \n\r\t]+');
  final Scanner scanner;

  @override
  final Map<Pattern, TokenType> patterns = {
    new RegExp('--([^\n]*)'): TokenType.comment,
    '@': TokenType.arroba,
    '->': TokenType.arrow,
    ':': TokenType.colon,
    ',': TokenType.comma,
    '.': TokenType.dot,
    '=': TokenType.equals,
    '!=': TokenType.notEquals,
    '[': TokenType.lBracket,
    ']': TokenType.rBracket,
    '{': TokenType.lCurly,
    '}': TokenType.rCurly,
    '(': TokenType.lParen,
    ')': TokenType.rParen,
    ';': TokenType.semi,
    '"': TokenType.doubleQuote,
    "'": TokenType.singleQuote,
    '|>': TokenType.pipeline,
    '..': TokenType.doubleDot,
    '...': TokenType.tripleDot,
    '!': TokenType.nonNull,
    'as!': TokenType.nonNullAs,
    '!.': TokenType.nonNullDot,
    '?': TokenType.nullable,
    '??=': TokenType.nullableAssign,
    '?.': TokenType.nullableDot,
    '??': TokenType.nullCoalescing,
    '**': TokenType.exponent,
    '*': TokenType.times,
    '/': TokenType.div,
    '%': TokenType.mod,
    '+': TokenType.plus,
    '-': TokenType.minus,
    '<<': TokenType.shiftLeft,
    '>>': TokenType.shiftRight,
    '&&': TokenType.booleanAnd,
    '||': TokenType.booleanOr,
    '<': TokenType.lessThan,
    '<=': TokenType.lessThanOrEqual,
    '>': TokenType.greaterThan,
    '>=': TokenType.greaterThanOrEqual,
    '~': TokenType.bitwiseNegate,
    '&': TokenType.bitwiseAnd,
    '|': TokenType.bitwiseOr,
    '^': TokenType.bitwiseXor,
    'abstract': TokenType.abstract$,
    'as': TokenType.as$,
    'await': TokenType.await$,
    'async': TokenType.async$,
    'async*': TokenType.asyncStar,
    'sync*': TokenType.syncStar,
    'begin': TokenType.begin,
    'class': TokenType.class$,
    'const': TokenType.const$,
    'else': TokenType.else$,
    'end': TokenType.end,
    'export': TokenType.export,
    'extends': TokenType.extends$,
    'fun': TokenType.fun,
    'hide': TokenType.hide,
    'if': TokenType.if$,
    'implements': TokenType.implements$,
    'import': TokenType.import,
    'in': TokenType.in$,
    'is': TokenType.is$,
    'is!': TokenType.isNot,
    'let': TokenType.let,
    'proto': TokenType.proto,
    'rec': TokenType.rec,
    'show': TokenType.show,
    'throw': TokenType.throw$,
    'type': TokenType.type,
    'val': TokenType.val,
    'step': TokenType.step,
    'false': TokenType.false$,
    'true': TokenType.true$,
    'null': TokenType.null$,
    new RegExp(r'0x([A-Fa-f0-9]+)'): TokenType.hex,
    new RegExp(r'0o([0-7]+)'): TokenType.octal,
    new RegExp(r'0b([0-1]+)'): TokenType.binary,
    new RegExp(r'[0-9]+'): TokenType.int$,
    new RegExp(r'([0-9]+)[Ee](-?[0-9]+)'): TokenType.intScientific,
    new RegExp(r'[0-9]+\.[0-9]+'): TokenType.double$,
    new RegExp(r'([0-9]+\.[0-9]+)[Ee](-?[0-9]+)'): TokenType.doubleScientific,
    new RegExp(r'([A-Za-z_]|\$)([A-Za-z0-9_]|\$)*'): TokenType.id,
  };

  NormalModeScanner(this.scanner);

  @override
  Token scan() {
    if (scanner.scanner.scan(whitespace)) {
      return null;
    }

    var token = super.scan();

    if (token?.type == TokenType.doubleQuote) {
      scanner.stateStack
          .addFirst(new StringModeScanner(scanner, TokenType.doubleQuote, '"'));
    } else if (token?.type == TokenType.singleQuote) {
      scanner.stateStack
          .addFirst(new StringModeScanner(scanner, TokenType.singleQuote, "'"));
    } else if (token?.type == TokenType.lCurly) {
      scanner.stateStack.addFirst(this);
    } else if (token?.type == TokenType.rCurly) {
      scanner.stateStack.removeFirst();
    }

    return token;
  }
}

class StringModeScanner extends SubScannerBase {
  final Scanner scanner;
  final TokenType delimiter;
  final String delimiterString;

  @override
  Map<Pattern, TokenType> patterns = {
    new RegExp(r'\\(b|f|n|r|t|\\)'): TokenType.escapeStringPart,
    new RegExp(r'\\[Xx]([A-Fa-f0-9][A-Fa-f0-9])'): TokenType.hexStringPart,
    new RegExp(r'\\[Uu]([A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9][A-Fa-f0-9])'): TokenType.unicodeStringPart,
    new RegExp(r'\\[Uu]{([A-Fa-f0-9]+)}'): TokenType.unicodeStringPart,
    new RegExp(r'\$([A-Za-z_])([A-Za-z0-9_])*'):
        TokenType.stringSingleInterpPart,
  };

  StringModeScanner(this.scanner, this.delimiter, this.delimiterString) {
    patterns['\\$delimiterString'] = TokenType.escapedQuotePart;
    patterns[new RegExp('[^$delimiterString\\\\]+')] = TokenType.textStringPart;
  }

  @override
  Token scan() {
    var s = scanner.scanner;
    if (s.matches(delimiterString)) {
      var token = new Token(delimiter, s.lastSpan, s.lastMatch);
      scanner.flush();
      s.scan(token.span.text);
      scanner.tokens.add(token);
      scanner.stateStack.removeFirst();
      return token;
    }

    var token = super.scan();

    if (token?.type == TokenType.stringInterpStart) {
      scanner.stateStack.addFirst(new NormalModeScanner(scanner));
    } else if (token?.type == TokenType.rCurly) {
      scanner.stateStack.removeFirst();
    } else if (token?.type == delimiter) {
      scanner.stateStack.removeFirst();
    }

    return token;
  }
}
