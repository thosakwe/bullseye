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
