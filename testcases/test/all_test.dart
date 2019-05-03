import 'dart:io';
import 'package:bullseye/bullseye.dart';
//import 'package:front_end/src/fasta/kernel/kernel_shadow_ast.dart';
import 'package:front_end/src/compute_platform_binaries_location.dart';
import 'package:front_end/src/api_prototype/front_end.dart';
import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:kernel/target/targets.dart';
import 'package:kernel/text/ast_to_text.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

var toSkip = <String>[];

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

      test(name, () async {
        // First, compile the bullseye source.
        var blsComponent = await compileBullseyeToKernel(
            await blsFile.readAsString(), p.toUri(blsPath), onException);

        var libsUri = await computePlatformBinariesLocation();
        var specUri =
            libsUri.replace(path: p.join(libsUri.path, '..', 'libraries.json'));
        var platformStrongUri = libsUri.resolve('vm_platform_strong.dill');
        var flags = new TargetFlags();
        var target = new NoneTarget(flags);

        CompilerOptions options = new CompilerOptions()
          ..target = target
          ..sdkSummary = platformStrongUri
          //..linkedDependencies = [platformStrongUri]
          ..librariesSpecificationUri = specUri
          ..packagesFileUri = await PackageResolver.current.packageConfigUri;

        var dartFileUri = new Uri(scheme: 'file', path: p.absolute(dartPath));
        // var dartComponent = await kernelForProgram(
        //     new Uri(scheme: 'file', path: p.absolute(dartPath)), options);
        var dartComponent = await kernelForComponent([dartFileUri], options);

        if (blsComponent == null)
          throw new StateError('Bullseye compilation failed.');
        else if (dartComponent == null)
          throw new StateError('Dart compilation failed.');

        // Remove all but the first library from the dart component.
        if (blsComponent != null) {
          dartComponent = new Component(
              libraries: [dartComponent.libraries[0]],
              nameRoot: dartComponent.root,
              uriToSource: dartComponent.uriToSource)
            ..mainMethod = dartComponent.mainMethod;

          dartComponent.libraries[0].importUri =
              blsComponent.libraries[0].importUri;
        }

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

        if (blsComponent != null)
          newPrinter(blsText).writeComponentFile(blsComponent);
        newPrinter(dartText).writeComponentFile(dartComponent);

        print('$name from Bullseye:\n$blsText');
        print('vs. $name from Dart:\n$dartText');
        expect(blsText.toString(), dartText.toString());
      },
          skip: toSkip.contains(p.basenameWithoutExtension(name))
              ? 'Skipping `$name` tests (for now)'
              : null);
    }
  }
}

void onException(BullseyeException exc) {
  print(exc.toString(showSpan: true, color: true));
}
