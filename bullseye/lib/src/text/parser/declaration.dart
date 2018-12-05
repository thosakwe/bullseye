import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

class DeclarationParser {
  final Parser parser;

  DeclarationParser(this.parser);

  CompilationUnit parseCompilationUnit() {
    var dirs = <Directive>[];
    var decl = <TopLevelDeclaration>[];
    var dir = parseDirective();

    while (dir != null) {
      dirs.add(dir);
      dir = parseDirective();
    }

    while (!parser.done) {
      var token = parser.peek();
      var d = parseTopLevelDeclaration();

      if (d != null) {
        decl.add(d);
        parser.flush();
      } else {
        parser
          ..moveNext()
          ..markErrant(token);
      }
    }

    parser.flush();

    if (decl.isNotEmpty || dirs.isNotEmpty) {
      FileSpan span;

      if (dirs.isNotEmpty) {
        span = dirs.map((d) => d.span).reduce((a, b) => a.expand(b));
        if (decl.isNotEmpty) {
          span = span
              .expand(decl.map((d) => d.span).reduce((a, b) => a.expand(b)));
        }
      } else {
        span = decl.map((d) => d.span).reduce((a, b) => a.expand(b));
      }

      return new CompilationUnit([], span, dirs, decl);
    } else {
      var span = parser.scanner.scanner.emptySpan;
      return new CompilationUnit([], span, dirs, decl);
    }
  }

  TopLevelDeclaration parseTopLevelDeclaration() {
    // TODO: Other options...?
    return parser.functionParser.parseFunctionDeclaration();
  }

  Directive parseDirective() {
    // TODO: Other directives
    return parseImportDirective();
  }

  ImportDirective parseImportDirective() {
    // TODO: Annotations + comments
    var annotations = <Annotation>[];
    var comments = <Token>[];

    if (parser.peek()?.type == TokenType.import && parser.moveNext()) {
      var span = parser.current.span;
      var url = parser.parseString();

      if (url != null && url.hasConstantValue) {
        Identifier alias;
        var show = <Identifier>[], hide = <Identifier>[];

        // Look for an alias
        if (parser.peek()?.type == TokenType.as$ && parser.moveNext()) {
          var as$ = parser.current;

          if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
            alias = new Identifier([], parser.current);
          } else {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                as$.span,
                "The '${as$}' keyword must be followed by an identifier."));
          }
        }

        // Look for show/hide (infinitely)
        while (const [TokenType.hide, TokenType.show]
                .contains(parser.peek()?.type) &&
            parser.moveNext()) {
          var token = parser.current;
          var out = parser.current.type == TokenType.hide ? hide : show;
          var added = 0;

          while (parser.peek()?.type == TokenType.id && parser.moveNext()) {
            var id = new Identifier([], parser.current);
            added++;
            out.add(id);

            while (parser.peek()?.type == TokenType.comma) {
              parser.moveNext(); // Skip commas
            }
          }

          if (added == 0) {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                token.span,
                "The '${token.span.text}' keyword must be followed by at least one identifier."));
          }
        }

        return new ImportDirective(
            annotations, comments, span, url, alias, hide, show);
      } else if (url != null && !url.hasConstantValue) {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            span,
            "The path to an imported library must be a constant string literal."));
        return null;
      } else {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            span,
            "Missing string after 'import' keyword."));
        return null;
      }
    } else {
      return null;
    }
  }
}
