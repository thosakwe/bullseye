import 'dart:io';
import 'package:args/args.dart';
import 'package:bullseye/bullseye.dart';
import 'package:kernel/kernel.dart';
import 'package:string_scanner/string_scanner.dart';

var argParser = new ArgParser()
  ..addFlag('help',
      abbr: 'h',
      negatable: false,
      defaultsTo: false,
      help: 'Print this help information.')
  ..addFlag('link',
      abbr: 'L',
      negatable: false,
      defaultsTo: false,
      help: 'Link a number of .dill files together.')
  ..addOption('format',
      abbr: 'f',
      allowed: ['binary', 'text'],
      defaultsTo: 'binary',
      help: 'The output format to write the kernel component to.')
  ..addOption('out', abbr: 'o', help: 'The path to write output to.');

main(List<String> args) async {
  try {
    var argResults = argParser.parse(args);
    Component outputComponent;

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
        var compiler = new BullseyeKernelCompiler(unit, parser);
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
      await writeComponentToBinary(
          outputComponent, argResults['out'] as String);
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
