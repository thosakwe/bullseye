import 'package:bullseye/bullseye.dart';
import 'package:cli_repl/cli_repl.dart';
import 'package:kernel/interpreter/interpreter.dart';
import 'package:string_scanner/string_scanner.dart';

main() async {
  var repl = new Repl(prompt: '>> ');

  await for (var line in repl.runAsync()) {
    var ss = new SpanScanner(line, sourceUrl: 'stdin');
    var scanner = new Scanner(ss)..scan();
    var parser = new Parser(scanner);
    var unit = parser.parse();
    var hasFatal = parser.exceptions
        .any((e) => e.severity == BullseyeExceptionSeverity.error);

    for (var error in parser.exceptions) {
      print(error.toString(showSpan: true, color: true));
    }

    if (!hasFatal) {
      var compiler = new BullseyeKernelCompiler(unit)..compile();
      var hasFatal = compiler.exceptions
          .any((e) => e.severity == BullseyeExceptionSeverity.error);

      for (var error in compiler.exceptions) {
        print(error.toString(showSpan: true, color: true));
      }

      if (!hasFatal) {
        var component = compiler.toComponent();
        var interpreter = new Interpreter(component);
        interpreter.run();
      }
    }
  }
}
