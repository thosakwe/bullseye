import 'dart:io';

import 'package:bullseye/bullseye.dart';
import 'package:cli_repl/cli_repl.dart';
import 'package:string_scanner/string_scanner.dart';

main(List<String> args) async {
  Future run(String text, sourceUrl) async {
    var ss = new SpanScanner(text, sourceUrl: sourceUrl);
    var scanner = new Scanner(ss)..scan();
    var parser = new Parser(scanner);
    var unit = parser.parse();
    var hasFatal = parser.exceptions
        .any((e) => e.severity == BullseyeExceptionSeverity.error);

    for (var error in parser.exceptions) {
      print(error.toString(showSpan: true, color: true));
    }

    if (!hasFatal) {
      var compiler = new BullseyeKernelCompiler(unit, parser);
      await compiler.initialize();
      compiler.compile();
      var hasFatal = compiler.exceptions
          .any((e) => e.severity == BullseyeExceptionSeverity.error);

      for (var error in compiler.exceptions) {
        print(error.toString(showSpan: true, color: true));
      }

      if (!hasFatal) {
        // TODO: Interpret (maybe via Dart VM service)???
        var component = compiler.toComponent();
        print(component);
        // var interpreter = new Interpreter(component);
        // interpreter.run();
      }
    }
  }

  if (args.isNotEmpty) {
    var file = new File(args[0]);
    await run(await file.readAsString(), file.uri);
  } else {
    var repl = new Repl(prompt: '>> ');
    await for (var line in repl.runAsync()) {
      await run(line, 'stdin');
    }
  }
}
