import 'dart:async';
import 'dart:io';
import 'package:buffer/buffer.dart';
import 'package:kernel/kernel.dart';

main(List<String> args) async {
  Stream<List<int>> input = args[0] == '-' ? stdin : File(args[0]).openRead();
  var bytes = await readAsBytes(input);
  var comp = loadComponentFromBytes(bytes);

  for (var lib in comp.libraries) {
    print('Found lib ${lib.name} from ${lib.fileUri}');
  }

  writeComponentToText(
    comp,
    showExternal: true,
    showMetadata: true,
    showOffsets: false,
  );
}
