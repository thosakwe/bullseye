import 'value.dart';

abstract class ValueVisitor<T> {
  T visitAwait(Await node);
  T visitBinaryOperation(BinaryOperation node);
  T visitBullseyeFunction(BullseyeFunction node); 
  T visitClassInit(ClassInit node);
  T visitConstBool(ConstBool node);
  T visitConstDouble(ConstDouble node);
  T visitConstInt(ConstInt node);
  T visitConstString(ConstString node);
  T visitConstUnit(ConstUnit node);
  T visitFunctionCall(FunctionCall node);
  T visitGetSymbol(GetSymbol node);
  T visitIOBind(IOBind node);
  T visitIfThen(IfThen node);
  T visitLetIn(LetIn node);
  T visitSetSymbol(SetSymbol node);
  T visitTaggedSumInit(TaggedSumInit node);
  T visitTuple(Tuple node);
  T visitWrapPureInIO(WrapPureInIO node);
}
