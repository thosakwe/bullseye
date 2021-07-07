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
  dart.Expression visitClassInit(ClassInit node) {
    // TODO: implement visitClassInit
    throw UnimplementedError();
  }

  @override
  dart.Expression visitConstBool(ConstBool node) {
    // TODO: implement visitConstBool
    throw UnimplementedError();
  }

  @override
  dart.Expression visitConstDouble(ConstDouble node) {
    // TODO: implement visitConstDouble
    throw UnimplementedError();
  }

  @override
  dart.Expression visitConstInt(ConstInt node) {
    // TODO: implement visitConstInt
    throw UnimplementedError();
  }

  @override
  dart.Expression visitConstString(ConstString node) {
    // TODO: implement visitConstString
    throw UnimplementedError();
  }

  @override
  dart.Expression visitConstUnit(ConstUnit node) {
    // TODO: implement visitConstUnit
    throw UnimplementedError();
  }

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
    // TODO: implement visitIfThen
    throw UnimplementedError();
  }

  @override
  dart.Expression visitLetIn(LetIn node) {
    // TODO: implement visitLetIn
    throw UnimplementedError();
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
    // TODO: implement visitTuple
    throw UnimplementedError();
  }

  @override
  dart.Expression visitWrapPureInIO(WrapPureInIO node) {
    // TODO: implement visitWrapPureInIO
    throw UnimplementedError();
  }
}
