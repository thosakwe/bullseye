import 'dart:io';
import 'package:args/args.dart';
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:bullseye_lang/src/ast/ast.dart';
import 'package:glob/glob.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/kernel.dart';
import 'package:string_scanner/string_scanner.dart';

var argParser = new ArgParser()
  ..addFlag('compile-only',
      abbr: 'c',
      negatable: false,
      help:
          'Compile only the given file, without including imported libraries.')
  ..addFlag('help',
      abbr: 'h',
      negatable: false,
      defaultsTo: false,
      help: 'Print this help information.')
  ..addFlag('link',
      abbr: 'L',
      negatable: false,
      defaultsTo: false,
      help:
          'Link a number of .dill files together, along with all third-party dependencies.')
  ..addOption('format',
      abbr: 'f',
      allowed: ['binary', 'text'],
      defaultsTo: 'binary',
      help: 'The output format to write the kernel component to.')
  ..addOption('out', abbr: 'o', help: 'The path to write output to.');

Future<void> linkAllDeps(Component cmp) async {
  var cmpp = BullseyeKernelCompiler(null, null);
  var dartTool = await cmpp.findDartToolFile();

  if (dartTool != null) {
    var glob = Glob('**/*.dill');
    await for (var entity in glob.list(root: dartTool)) {
      if (entity is File) {
        // print(entity.path);
        await loadComponentFromBinary(entity.path, cmp);
      }
    }
  }
}

main(List<String> args) async {
  try {
    var argResults = argParser.parse(args);
    Component outputComponent;
    BullseyeKernelCompiler compiler;

    if (argResults['help'] as bool) {
      stdout
        ..writeln('usage: blsc [options...] <inputs>')
        ..writeln('Options:')
        ..writeln()
        ..writeln(argParser.usage);
      return;
    } else if (!argResults.wasParsed('out') &&
        argResults['format'] == 'binary') {
      throw new ArgParserException(
          'If --out is not defined, blsc can only print binary data to stdout.');
    } else if (argResults.rest.isEmpty) {
      throw new ArgParserException('No inputs were provided.');
    } else if (argResults['link'] as bool) {
      // Just load components, and then link together into one.
      outputComponent = new Component();
      await Future.wait(argResults.rest.map((filename) async {
        return loadComponentFromBinary(filename, outputComponent);
      }));

      // Next, load all dependencies.
      await linkAllDeps(outputComponent);

      // var libs = outputComponent.libraries.toList();
      // var cmp = BullseyeKernelCompiler(null, null);
      // var resolver = await cmp.createPackageResolver();
      // for (var lib in libs) {
      //   for (var dep in lib.dependencies) {
      //     if (dep is LibraryDependency) {

      //     }
      //     // var loaded = await compiler.loadLibrary(dep.targetLibrary);
      //   }
      // }
    } else if (argResults.rest.length != 1) {
      throw new ArgParserException(
          'If --link is not specified, only one input file is allowed.');
    } else {
      var filename = argResults.rest.first;
      var file = new File(filename);
      var contents = await file.readAsString();
      var ss = new SpanScanner(contents, sourceUrl: file.uri);
      var scanner = new Scanner(ss)..scan();
      var parser = new Parser(scanner);
      var unit = parser.parse();

      var hasFatal = parser.exceptions
          .any((e) => e.severity == BullseyeExceptionSeverity.error);

      for (var error in parser.exceptions) {
        print(error.toString(showSpan: true, color: true));
      }

      if (!hasFatal) {
        compiler = new BullseyeKernelCompiler(unit, parser,
            bundleExternal: !(argResults['compile-only'] as bool));
        await compiler.initialize();
        compiler.compile();
        var hasFatal = compiler.exceptions
            .any((e) => e.severity == BullseyeExceptionSeverity.error);

        for (var error in compiler.exceptions) {
          print(error.toString(showSpan: true, color: true));
        }

        if (!hasFatal) {
          outputComponent = compiler.toComponent();
        } else {
          throw new StateError(
              'Compilation failed with ${compiler.exceptions.where((e) => e.severity == BullseyeExceptionSeverity.error).length} fatal error(s).');
        }
      } else {
        throw new StateError(
            'Parsing failed with ${parser.exceptions.where((e) => e.severity == BullseyeExceptionSeverity.error).length} fatal error(s).');
      }
    }

    bool isStdout = !argResults.wasParsed('out');
    IOSink sink;

    if (isStdout)
      sink = stdout;
    else {
      var file = new File(argResults['out'] as String);
      await file.create(recursive: true);
      sink = file.openWrite();
    }

    if (argResults['format'] == 'text') {
      writeComponentToText(outputComponent,
          path: isStdout ? null : argResults['out'] as String);
    } else {
      if (compiler != null) {
        await compiler.emit(sink);
      } else {
        var p = BinaryPrinter(sink);
        p.writeComponentFile(outputComponent);
      }

      if (!isStdout) await sink.close();
      // await writeComponentToBinary(
      //     outputComponent, argResults['out'] as String);
    }

    if (isStdout) await sink.close();
  } on ArgParserException catch (e) {
    exitCode = 1;
    stderr
      ..writeln(e.message)
      ..writeln()
      ..writeln('usage: blsc [options...] <inputs>')
      ..writeln('Options:')
      ..writeln()
      ..writeln(argParser.usage);
  } on StateError catch (e) {
    exitCode = 1;
    stderr.writeln(e.message);
  } catch (e, st) {
    exitCode = 1;
    stderr..writeln(e)..writeln(st);
  }
}
