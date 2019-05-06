import 'dart:io';
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:io/ansi.dart';
import 'package:kernel/kernel.dart';
import 'package:path/path.dart' as p;
import 'package:string_scanner/string_scanner.dart';
import 'blsc.dart';

main(List<String> args) async {
  try {
    int fnIndex = -1;

    for (int i = 0; i < args.length; i++) {
      if (args[i].endsWith('.bls')) {
        fnIndex = i;
        break;
      }
    }

    if (fnIndex == -1) {
      stderr
        ..writeln(red.wrap('fatal error: no *.bls input file was given.'))
        ..writeln(red.wrap('usage: bullseye [options...] <input.bls>'))
        ..writeln(red.wrap(
            '\twhere `options` are forwarded to ${Platform.resolvedExecutable}'));
      exitCode = 65;
      return;
    }

    var file = new File(args[fnIndex]);
    var text = await file.readAsString();
    var ss = new SpanScanner(text, sourceUrl: file.uri);
    var scanner = new Scanner(ss)..scan();
    var parser = new Parser(scanner);
    var unit = parser.parse();
    var hasFatal = parser.exceptions
        .any((e) => e.severity == BullseyeExceptionSeverity.error);
    File dillFile;
    Directory tempDir;

    for (var error in parser.exceptions) {
      print(error.toString(showSpan: true, color: true));
    }

    if (!hasFatal) {
      var compiler =
          new BullseyeKernelCompiler(unit, parser, bundleExternal: true);
      await compiler.initialize();
      compiler.compile();
      var hasFatal = compiler.exceptions
          .any((e) => e.severity == BullseyeExceptionSeverity.error);

      for (var error in compiler.exceptions) {
        print(error.toString(showSpan: true, color: true));
      }

      if (!hasFatal) {
        // We manage a Dart process in the background.
        // We send the generated source over.
        if (dillFile == null) {
          tempDir = await Directory.systemTemp.createTemp();
          dillFile = File(p.join(tempDir.path, 'bullseye_top.dill'));
        }

        // Compile the dill, and save it.
        // var component = compiler.toComponent();
        args[fnIndex] = dillFile.path;
        var sink = await dillFile.openWrite();
        // await compiler.emit(sink);
        await sink.close();
        // await dillFile.writeAsBytes(compiler.bundle());
        var cmp = compiler.toComponent();
        await linkAllDeps(cmp);
        await writeComponentToBinary(cmp, dillFile.path);

        // Start dart, if it isn't already.
        var dart = await Process.start(Platform.resolvedExecutable, args,
            mode: ProcessStartMode.inheritStdio);
        exitCode = await dart.exitCode;
      }
    } else {
      exitCode = 1;
    }
  } catch (e, st) {
    if (!bool.fromEnvironment('BULLSEYE_DEBUG')) {
      rethrow;
    } else {
      stderr
        ..writeln(yellow.wrap(e.toString()))
        ..writeln(yellow.wrap(st.toString()));
    }
  }
}
