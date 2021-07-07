import 'value.dart';

abstract class ValueVisitor<T> {
  T visitConstDouble(ConstDouble node);
  T visitConstInt(ConstInt node);
  T visitConstString(ConstString node);
  T visitConstUnit(ConstUnit node);
  T visitTuple(Tuple node);
  T visitIfThen(IfThen node);
  T visitFunctionCall(FunctionCall node);
  T visitLetIn(LetIn node);
  T visitBinaryOperation(BinaryOperation node);
  T visitBullseyeFunction(BullseyeFunction node); 
  T visitAwait(Await node);
  T visitIOBind(IOBind node);
  T visitWrapPureInIO(WrapPureInIO node);
  T visitClassInit(ClassInit node);
  T visitTaggedSumInit(TaggedSumInit node);
  T visitGetSymbol(GetSymbol node);
  T visitSetSymbol(SetSymbol node);
}
