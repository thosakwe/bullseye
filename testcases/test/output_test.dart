import 'dart:convert';
import 'dart:io';
import 'package:bullseye/bullseye.dart';
import 'package:glob/glob.dart';
import 'package:kernel/kernel.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('output', testTextOutput);
}

void onException(BullseyeException exc) {
  print(exc.toString(showSpan: true, color: true));
}

void testTextOutput() {
  var glob = Glob('*.bls');
  var tempDir = Directory.systemTemp.createTempSync();

  for (var blsFile in glob.listSync()) {
    if (blsFile is File) {
      var blsPath = blsFile.path;
      var textFile = p.setExtension(blsPath, '.txt');
      var name = p.basename(blsPath);

      test(name, () async {
        // Compile the Bullseye file, write to a temp file.
        var blsComponent = await compileBullseyeToKernel(
            await blsFile.readAsString(), p.toUri(blsPath), onException);
        expect(blsComponent, isNotNull);
        var dillFile = p.setExtension(p.join(tempDir.path, name), '.dill');
        await writeComponentToBinary(blsComponent, dillFile);

        // Next, run the dill file.
        var dart = await Process.start('dart', [dillFile]);
        stderr.addStream(dart.stderr);
        await dart.exitCode;

        var actual = await dart.stdout.transform(utf8.decoder).join();
        var expected = await File(textFile).readAsString();
        expect(actual.trim(), expected.trim());
      });
    }
  }
}
