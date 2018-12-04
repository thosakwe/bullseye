import 'package:bullseye/bullseye.dart';

typedef T PrefixParselet<T>(Parser parser, Token token);

typedef T InfixParselet<T>(Parser parser, T left, Token token);

abstract class PrattParser<T> {
  final Parser parser;

  final Map<TokenType, PrefixParselet<T>> _prefixParselets = {};

  final Map<TokenType, InfixParselet<T>> _infixParselets = {};

  PrattParser(this.parser);

  InfixParselet<T> _nextInfix = null;

  int get _nextPrecedence {
    int i = 0;

    for (var entry in _infixParselets.entries) {
      if (parser.peek()?.type == entry.key) {
        _nextInfix = entry.value;
        return i;
      } else {
        i++;
      }
    }

    return 0;
  }

  T parse([int precedence = 0]) {
    var next = parser.peek();
    if (_prefixParselets.containsKey(next.type) && parser.moveNext()) {
      var left = _prefixParselets[next.type](parser, next);

      while (left != null &&
          precedence < _nextPrecedence &&
          parser.moveNext()) {
        left = _nextInfix(parser, left, parser.current);
      }

      return left;
    } else {
      return null;
    }
  }

  void addPrefix(TokenType type, PrefixParselet<T> f) {
    _prefixParselets[type] = f;
  }

  void addInfix(TokenType type, InfixParselet<T> f) {
    _infixParselets[type] = f;
  }
}
