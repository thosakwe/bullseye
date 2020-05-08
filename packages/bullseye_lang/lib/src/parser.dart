import 'dart:collection';
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';

class Parser {
  final List<BullseyeError> errors;
  final Iterator<Token> tokens;

  final Queue<Token> _tokenQueue = Queue();
  ExprParser _exprParser;
  TypeParser _typeParser;
  Token _lastToken;

  Parser(Iterable<Token> tokens, this.errors) : tokens = tokens.iterator;

  factory Parser.fromLexer(Lexer lexer) =>
      Parser(lexer.produceTokens(), lexer.errors);

  ExprParser get exprParser => _exprParser ??= ExprParser(this);

  TypeParser get typeParser => _typeParser ??= TypeParser(this);

  Token get lastToken => _lastToken;

  bool nextIs(TokenType type) => nextIsAnyOf([type]);

  bool nextIsAnyOf(Iterable<TokenType> types) {
    if (_tokenQueue.isNotEmpty) {
      if (types.contains(_tokenQueue.first.type)) {
        _lastToken = _tokenQueue.removeFirst();
        return true;
      } else {
        return false;
      }
    } else if (tokens.moveNext()) {
      if (types.contains(tokens.current.type)) {
        _lastToken = tokens.current;
        return true;
      } else {
        _tokenQueue.addLast(tokens.current);
        return false;
      }
    } else {
      return false;
    }
  }

  void emitError(FileSpan lastSpan, String message) {
    errors.add(BullseyeError(lastSpan, BullseyeErrorSeverity.error, message));
  }
}
