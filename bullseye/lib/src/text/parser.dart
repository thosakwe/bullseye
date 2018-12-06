import 'dart:collection';
import 'package:bullseye/bullseye.dart';
export 'parser/parser.dart';

class Parser extends ScannerIterator {
  final List<BullseyeException> exceptions = [];
  DeclarationParser declarationParser;
  ExpressionParser expressionParser;
  FunctionParser functionParser;
  TypeParser typeParser;

  final Queue<Token> _errant = new Queue();

  Parser(Scanner scanner) : super(scanner) {
    declarationParser = new DeclarationParser(this);
    expressionParser = new ExpressionParser(this);
    functionParser = new FunctionParser(this);
    typeParser = new TypeParser(this);
    exceptions.addAll(scanner.exceptions);
  }

  CompilationUnit parse() => declarationParser.parseCompilationUnit();

  @override
  T runOrBacktrack<T>(f) {
    var old = new List<BullseyeException>.from(exceptions);
    var result = super.runOrBacktrack(f);
    if (result == null) {
      exceptions.removeWhere((e) => !old.contains(e));
    }
    return result;
  }

  void markErrant([Token token]) {
    _errant.addLast(token ?? current);
  }

  void flush() {
    if (_errant.isNotEmpty) {
      var span = _errant.map((t) => t.span).reduce((a, b) => a.expand(b));
      _errant.clear();
      exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error, span, "Unexpected text."));
    }
  }

  UnitLiteral parseUnit() {
    if (peek()?.type == TokenType.lParen && moveNext()) {
      var lParen = current;

      if (peek()?.type == TokenType.rParen && moveNext()) {
        return new UnitLiteral(lParen.span.expand(current.span));
      } else if (done) {
        exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            lParen.span, "Expected ')' after '(', found end-of-file instead."));
      } else {
        movePrevious();
      }
    }

    return null;
  }

  StringLiteral parseString([Token token]) {
    if (token == null) {
      // TODO: Raw Strings, triple quotes
      if (peek()?.type == TokenType.doubleQuote && moveNext()) {
        token = current;
      } else if (peek()?.type == TokenType.singleQuote && moveNext()) {
        token = current;
      } else {
        return null;
      }
    }

    var parts = <StringPart>[];
    var span = token.span, lastSpan = span;
    var part = parseStringPart();

    while (part != null) {
      parts.add(part);
      span = span.expand(lastSpan = part.span);
      part = parseStringPart();
    }

    // Expect closing...
    if (peek()?.type == token.type && moveNext()) {
      var out = new StringLiteral([], span.expand(current.span), parts);

      // Add adjacent
      var next = parseString();
      while (next != null) {
        out = new StringLiteral(out.comments, span,
            new List<StringPart>.from(out.parts)..addAll(next.parts));
        next = parseString();
      }

      return out;
    } else {
      exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
          lastSpan, "Unterminated string literal; expected '${token.span}'."));
      return null;
    }
  }

  StringPart parseStringPart() {
    var la = peek();
    if (la?.type == TokenType.textStringPart && moveNext()) {
      return new TextStringPart(current.span);
    } else if (la?.type == TokenType.escapeStringPart && moveNext()) {
      return new EscapeStringPart(current);
    } else if (la?.type == TokenType.escapedQuotePart && moveNext()) {
      return new EscapeStringPart(current);
    } else if (la?.type == TokenType.unicodeStringPart && moveNext()) {
      return new EscapeStringPart(current);
    } else if (la?.type == TokenType.hexStringPart && moveNext()) {
      return new HexStringPart(current);
    } else if (la?.type == TokenType.stringSingleInterpPart && moveNext()) {
      var name = la.span.text.substring(1);
      var id = new Identifier([], la, name);
      return new InterpolationStringPart(id);
    } else if (la?.type == TokenType.stringInterpStart) {
      var expr = expressionParser.parse();

      if (expr != null) {
        if (peek()?.type != TokenType.rCurly || !moveNext()) {
          exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              expr.span,
              "Missing '}' after expression in string interpolation."));
        }

        return new InterpolationStringPart(expr);
      } else {
        exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            la.span,
            "Missing expression for string interpolation after '\$'."));
        return null;
      }
    } else {
      return null;
    }
  }
}
