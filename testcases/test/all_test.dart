import 'dart:io';
import 'package:bullseye/bullseye.dart';
//import 'package:front_end/src/fasta/kernel/kernel_shadow_ast.dart';
import 'package:front_end/src/testing/compiler_common.dart';
import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:kernel/text/ast_to_text.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('identical', testIdenticalOutput);
}

void testIdenticalOutput() {
  var glob = Glob('*.bls');

  for (var blsFile in glob.listSync()) {
    if (blsFile is File) {
      var blsPath = blsFile.path;
      var name = p.basename(blsPath);
      var dartPath = p.setExtension(blsPath, '.dart');
      var dartFile = new File(dartPath);

      test(name, () async {
        // First, compile the bullseye source.
        var blsComponent = await compileBullseyeToKernel(
            await blsFile.readAsString(), p.toUri(blsPath), onException);
        var dartComponent = await compileScript(await dartFile.readAsString());

        if (blsComponent == null)
          throw new StateError('Bullseye compilation failed.');
        else if (dartComponent == null)
          throw new StateError('Dart compilation failed.');

        // Remove all but the first library from the dart component.
        dartComponent = new Component(
            libraries: [dartComponent.libraries[0]],
            nameRoot: dartComponent.root,
            uriToSource: dartComponent.uriToSource)
          ..mainMethod = dartComponent.mainMethod;

        dartComponent.libraries[0].importUri =
            blsComponent.libraries[0].importUri;

        // AD HOC
        // var r = dartComponent.mainMethod.function.body as ReturnStatement;
        // var x = r.expression as MethodInvocationJudgment;
        // throw x.interfaceTarget;

        var blsText = new StringBuffer();
        var dartText = new StringBuffer();

        Printer newPrinter(StringBuffer txt) {
          return new Printer(txt,
              showExternal: false, showMetadata: false, showOffsets: false);
        }

        newPrinter(blsText).writeComponentFile(blsComponent);
        newPrinter(dartText).writeComponentFile(dartComponent);

        print('$name from Bullseye:\n$blsText');
        print('vs. $name from Dart:\n$dartText');
        expect(blsText.toString(), dartText.toString());
      });
    }
  }
}

void onException(BullseyeException exc) {
  print(exc.toString(showSpan: true, color: true));
}
