import 'package:code_builder/code_builder.dart' as dart;

class BlockContext {
  final dart.BlockBuilder block;
  final dart.MethodBuilder method;
  final bool canReturn;

  BlockContext(this.block, this.method, this.canReturn);

  BlockContext withBlock(dart.BlockBuilder block) =>
      BlockContext(block, method, false);

  BlockContext withMethod(dart.MethodBuilder method) =>
      BlockContext(block, method, false);

  BlockContent withReturnAllowed() => BlockContext(block, method, true);
}
