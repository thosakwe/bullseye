import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:string_scanner/string_scanner.dart';

Future<void> main(List<String> args) async {
  Stream<List<int>> data;
  String sourceUrl;

  if (args.isEmpty) {
    data = stdin;
    sourceUrl = 'stdin';
  } else {
    var file = File(args[0]);
    data = file.openRead();
    sourceUrl = file.path;
  }

  var text = await data.transform(utf8.decoder).join();
  var scanner = SpanScanner(text, sourceUrl: sourceUrl);
  var lexer = Lexer(scanner);
  var parser = Parser.fromLexer(lexer);
  var expr = parser.exprParser.parseExpression(allowDefinitions: true);
  if (expr != null) {
    print(expr);
  }
  parser.errors.forEach(print);
}
