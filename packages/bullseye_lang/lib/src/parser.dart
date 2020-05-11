import 'dart:collection';
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:source_span/source_span.dart';

class Parser {
  final List<BullseyeError> errors;
  final Iterator<Token> tokens;

  final Queue<Token> _tokenQueue = Queue();
  var _isDone = false;
  DeclParser _declParser;
  DirectiveParser _directiveParser;
  ExprParser _exprParser;
  PatternParser _patternParser;
  TypeParser _typeParser;
  Token _lastToken;

  Parser(Iterable<Token> tokens, this.errors) : tokens = tokens.iterator;

  factory Parser.fromLexer(Lexer lexer) =>
      Parser(lexer.produceTokens(), lexer.errors);

  DeclParser get declParser => _declParser ??= DeclParser(this);

  DirectiveParser get directiveParser =>
      _directiveParser ??= DirectiveParser(this);

  ExprParser get exprParser => _exprParser ??= ExprParser(this);

  PatternParser get patternParser => _patternParser ??= PatternParser(this);

  TypeParser get typeParser => _typeParser ??= TypeParser(this);

  bool get isDone => _isDone;

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
      _isDone = true;
      return false;
    }
  }

  void emitError(FileSpan lastSpan, String message) {
    errors.add(BullseyeError(lastSpan, BullseyeErrorSeverity.error, message));
  }

  CompilationUnitNode parseCompilationUnit(FileSpan emptySpan) {
    var directives = <DirectiveNode>[];
    var decls = <DeclNode>[];
    FileSpan span;

    var directive = directiveParser.parseDirective();
    while (directive != null) {
      directives.add(directive);
      if (span == null) {
        span = directive.span;
      } else {
        span = span.expand(directive.span);
      }
      directive = directiveParser.parseDirective();
    }

    var decl = declParser.parseDecl();
    while (decl != null) {
      decls.add(decl);
      if (span == null) {
        span = decl.span;
      } else {
        span = span.expand(decl.span);
      }
      decl = declParser.parseDecl();
    }

    if (directives.isEmpty && decls.isEmpty) {
      return CompilationUnitNode(emptySpan, [], []);
    } else {
      return CompilationUnitNode(span, directives, decls);
    }
  }
}
