import 'dart:convert';
import 'dart:io';
import 'package:bullseye/bullseye.dart';
import 'package:glob/glob.dart';
import 'package:io/ansi.dart';
import 'package:kernel/kernel.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/text/ast_to_text.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('output', testTextOutput);
}

void onException(BullseyeException exc) {
  print(exc.toString(showSpan: true, color: true));
}

void testTextOutput() {
  var glob = Glob('test/output/*.bls');
  var tempDir = Directory.systemTemp.createTempSync();

  for (var blsFile in glob.listSync()) {
    if (blsFile is File) {
      var blsPath = blsFile.path;
      var textFile = p.setExtension(blsPath, '.txt');
      var name = p.basename(blsPath);

      test(name, () async {
        // Compile the Bullseye file, write to a temp file.
        var blsComponent = await compileBullseyeToKernel(
            await blsFile.readAsString(),
            File(blsPath).absolute.uri,
            onException);
        expect(blsComponent, isNotNull);

        var blsText = new StringBuffer();

        Printer newPrinter(StringBuffer txt) {
          return new Printer(txt,
              showExternal: false, showMetadata: false, showOffsets: false);
        }

        if (blsComponent != null) {
          newPrinter(blsText).writeComponentFile(blsComponent);
          print(blsText);
        }

        var dillFile = p.setExtension(p.join(tempDir.path, name), '.dill');
        await writeComponentToBinary(blsComponent, dillFile);

        // Next, run the dill file.
        var dart = await Process.start('dart', [dillFile]);
        dart.stderr
            .transform(utf8.decoder)
            .transform(LineSplitter())
            .map(red.wrap)
            .listen(stderr.writeln);
        expect(await dart.exitCode, 0);

        var actual = await dart.stdout.transform(utf8.decoder).join();
        var expected = await File(textFile).readAsString();
        expect(actual.trim(), expected.trim());
      });
    }
  }
}
