import 'value.dart';

/// Base class for [BullseyeValue] visitors.
abstract class ValueVisitor<T> {
  T visitAwait(Await node);
  T visitBinaryOperation(BinaryOperation node);
  T visitConstBool(ConstBool node);
  T visitConstDouble(ConstDouble node);
  T visitConstInt(ConstInt node);
  T visitConstString(ConstString node);
  T visitConstUnit(ConstUnit node);
  T visitFunctionCall(FunctionCall node);
  T visitGetSymbol(GetSymbol node);
  T visitIfThen(IfThen node);
  T visitLetIn(LetIn node);
  T visitTuple(Tuple node);
}

/// Base class for [BullseyeValue] visitors that take an additional argument.
abstract class ValueVisitorArg1<Ctx, T> {
  T visitAwait(Ctx ctx, Await node);
  T visitBinaryOperation(Ctx ctx, BinaryOperation node);
  T visitConstBool(Ctx ctx, ConstBool node);
  T visitConstDouble(Ctx ctx, ConstDouble node);
  T visitConstInt(Ctx ctx, ConstInt node);
  T visitConstString(Ctx ctx, ConstString node);
  T visitConstUnit(Ctx ctx, ConstUnit node);
  T visitFunctionCall(Ctx ctx, FunctionCall node);
  T visitGetSymbol(Ctx ctx, GetSymbol node);
  T visitIfThen(Ctx ctx, IfThen node);
  T visitLetIn(Ctx ctx, LetIn node);
  T visitTuple(Ctx ctx, Tuple node);
}
