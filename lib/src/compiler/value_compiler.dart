import 'package:bullseye_lang/src/analysis/function_target.dart';
import 'package:bullseye_lang/src/analysis/function_target_visitor.dart';
import 'package:bullseye_lang/src/analysis/value.dart';
import 'package:bullseye_lang/src/analysis/value_visitor.dart';
import 'package:code_builder/code_builder.dart' as dart;

import 'context.dart';

/// Will be deleted soon anyways.
@deprecated
class ValueCompiler
    implements
        ValueVisitor<dart.Expression>,
        FunctionTargetVisitor<dart.Expression> {
  final Context context;

  ValueCompiler(this.context);

  @override
  dart.Expression visitAwait(Await node) => node.accept(this).awaited;

  @override
  dart.Expression visitBinaryOperation(BinaryOperation node) {
    // TODO: implement visitBinaryOperation
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
  dart.Expression visitGetSymbol(GetSymbol node) =>
      dart.refer(node.symbol.name);

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
  dart.Expression visitTuple(Tuple node) {
    // Create an instance of TupleN
    final args = node.items.map((item) => item.accept(this));
    return dart.refer('Tuple${node.items.length}').newInstance(args);
  }

  @override
  dart.Expression visitDirectTarget(DirectTarget node) =>
      throw UnimplementedError();

  @override
  dart.Expression visitIndirectTarget(IndirectTarget node) =>
      throw UnimplementedError();

  @override
  dart.Expression visitPartialTarget(PartialTarget node) =>
      throw UnimplementedError();

  @override
  dart.Expression visitConstructor(Constructor node) =>
      throw UnimplementedError();
}
