import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:cli_repl/cli_repl.dart';
import 'package:string_scanner/string_scanner.dart';

main() async {
  var repl = new Repl(prompt: '>> ');

  await for (var line in repl.runAsync()) {
    var ss = new SpanScanner(line, sourceUrl: 'stdin');
    var scanner = new Scanner(ss);
    scanner.scan();

    for (var error in scanner.exceptions) {
      print(error);
    }

    scanner.tokens.forEach(print);
  }
}
