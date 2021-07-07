import 'package:code_builder/code_builder.dart' as dart;
import 'package:bullseye_lang/src/analysis/value.dart';
import 'package:bullseye_lang/src/analysis/value_visitor.dart';

import 'context.dart';

class ValueCompiler extends ValueVisitor<dart.Expression> {
  final Context context;

  ValueCompiler(this.context);

  @override
  dart.Expression visitAwait(Await node) {
    // TODO: implement visitAwait
    throw UnimplementedError();
  }

  @override
  dart.Expression visitBinaryOperation(BinaryOperation node) {
    // TODO: implement visitBinaryOperation
    throw UnimplementedError();
  }

  @override
  dart.Expression visitBullseyeFunction(BullseyeFunction node) {
    // TODO: implement visitBullseyeFunction
    throw UnimplementedError();
  }

  @override
  dart.Expression visitConstBool(ConstBool node) =>
      dart.literalBool(node.value);

  @override
  dart.Expression visitConstDouble(ConstDouble node) =>
      dart.literalNum(node.value);

  @override
  dart.Expression visitConstInt(ConstInt node) => dart.literalNum(node.value);

  @override
  dart.Expression visitConstString(ConstString node) =>
      dart.literalString(node.value);

  @override
  dart.Expression visitConstUnit(ConstUnit node) => dart.literalNull;

  @override
  dart.Expression visitFunctionCall(FunctionCall node) {
    // TODO: implement visitFunctionCall
    throw UnimplementedError();
  }

  @override
  dart.Expression visitGetSymbol(GetSymbol node) {
    // TODO: implement visitGetSymbol
    throw UnimplementedError();
  }

  @override
  dart.Expression visitIOBind(IOBind node) {
    // TODO: implement visitIOBind
    throw UnimplementedError();
  }

  @override
  dart.Expression visitIfThen(IfThen node) {
    // Compiles to a conditional expression
    final whenTrue = node.whenTrue.accept(this);
    final whenFalse = node.whenFalse.accept(this);
    return node.condition.accept(this).conditional(whenTrue, whenFalse);
  }

  @override
  dart.Expression visitLetIn(LetIn node) {
    // let x = value in <body> is just sugar for (\x -> <body>)(<value>) in
    // lambda calculus.
    final body = dart.Method((b) {
      b.requiredParameters.add(dart.Parameter((b) => b.name = node.name));
      b.body = node.body.accept(this).returned.code;
    });
    return body.closure.call([node.value.accept(this)]);
  }

  @override
  dart.Expression visitSetSymbol(SetSymbol node) {
    // TODO: implement visitSetSymbol
    throw UnimplementedError();
  }

  @override
  dart.Expression visitTaggedSumInit(TaggedSumInit node) {
    // TODO: implement visitTaggedSumInit
    throw UnimplementedError();
  }

  @override
  dart.Expression visitTuple(Tuple node) {
    // Create an instance of TupleN
    final args = node.items.map((item) => item.accept(this));
    return dart.refer('Tuple${node.items.length}').newInstance(args);
  }

  @override
  dart.Expression visitWrapPureInIO(WrapPureInIO node) {
    // TODO: implement visitWrapPureInIO
    throw UnimplementedError();
  }
}
