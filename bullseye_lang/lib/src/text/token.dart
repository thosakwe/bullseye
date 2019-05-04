import 'package:source_span/source_span.dart';
import 'token_type.dart';

class Token {
  final TokenType type;
  final FileSpan span;
  final Match match;

  Token(this.type, this.span, this.match);

  @override
  String toString() {
    return '${span.start.toolString}: "${span.text}" -> $type';
  }
}
