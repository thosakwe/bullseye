import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:cli_repl/cli_repl.dart';
import 'package:io/ansi.dart';
import 'package:kernel/kernel.dart';
import 'package:path/path.dart' as p;
import 'package:string_scanner/string_scanner.dart';
import 'package:vm_service_lib/vm_service_lib.dart';
import 'package:vm_service_lib/vm_service_lib_io.dart';

main(List<String> args) async {
  Future run(String text, sourceUrl) async {
    var ss = new SpanScanner(text, sourceUrl: sourceUrl);
    var scanner = new Scanner(ss)..scan();
    var parser = new Parser(scanner);
    var unit = parser.parse();
    var hasFatal = parser.exceptions
        .any((e) => e.severity == BullseyeExceptionSeverity.error);
    var _ws = RegExp(r'[ \r\n\t]+');
    Process dart;
    File dillFile;
    Directory tempDir;
    StreamQueue<String> lines;
    VmService vmService;
    VM vm;
    IsolateRef mainIsolate;

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
        // We manage a Dart process in the background.
        // We send the generated source over.
        if (dillFile == null) {
          tempDir = await Directory.systemTemp.createTemp();
          dillFile = File(p.join(tempDir.path, 'bullseye_top.dill'));
        }

        // Compile the dill, and save it.
        var component = compiler.toComponent();
        await writeComponentToBinary(component, dillFile.path);

        // Start dart, if it isn't already.
        if (dart == null) {
          dart = await Process.start(Platform.resolvedExecutable, [
            '--observe=0',
            dillFile.path,
          ]);
          dart.stderr
              .transform(utf8.decoder)
              .transform(LineSplitter())
              .map(red.wrap)
              .listen(stderr.writeln);

          scheduleMicrotask(() async {
            await dart.exitCode.then((_) {
              // Reset dart to null...
              print('Died');
              dart = null;
            });
          });

          var lineStream =
              dart.stdout.transform(utf8.decoder).transform(LineSplitter());
          lines = StreamQueue(lineStream);

          while (await lines.hasNext) {
            var line = await lines.next;
            if (!line.startsWith('Observatory listening on')) {
              print(line);
            } else {
              var uri = Uri.parse(line.split(_ws).last).replace(scheme: 'ws');
              vmService = await vmServiceConnectUri(uri.toString());
              vm = await vmService.getVM();
              mainIsolate = vm.isolates[0];
              lines.rest.listen(print);
              break;
            }
          }
        } else {
          // Attempt to hot-reload...
          var report = await vmService.reloadSources(mainIsolate.id);
          if (!report.success) {
            print('Reload failed. :(');
          }
        }
      }
    }
  }

  if (args.isNotEmpty) {
    var file = new File(args[0]);
    await run(await file.readAsString(), file.uri);
  } else {
    var repl = new Repl(prompt: '>> ');
    for (var line in repl.run()) {
      await run(line, 'stdin');
    }
  }
}
