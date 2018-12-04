import 'package:bullseye/bullseye.dart';

class DeclarationParser {
  final Parser parser;

  DeclarationParser(this.parser);

  CompilationUnit parseCompilationUnit() {
    var decl = <TopLevelDeclaration>[];

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

    if (decl.isNotEmpty) {
      var span = decl.map((d) => d.span).reduce((a, b) => a.expand(b));
      return new CompilationUnit([], span, decl);
    } else {
      var span = parser.scanner.scanner.emptySpan;
      return new CompilationUnit([], span, decl);
    }
  }

  TopLevelDeclaration parseTopLevelDeclaration() {
    // TODO: Other options...?
    return parser.functionParser.parseFunctionDeclaration();
  }
}
