import 'value.dart';

abstract class ValueVisitor<Ctx, T> {
  Ctx visitConstDouble(Ctx ctx, ConstDouble node);
  Ctx visitConstInt(Ctx ctx, ConstInt node);
  Ctx visitConstString(Ctx ctx, ConstString node);
  Ctx visitConstUnit(Ctx ctx, ConstUnit node);
  Ctx visitTuple(Ctx ctx, Tuple node);
  Ctx visitIfThen(Ctx ctx, IfThen node);
  Ctx visitFunctionCall(Ctx ctx, FunctionCall node);
  Ctx visitLetIn(Ctx ctx, LetIn node);
  Ctx visitBinaryOperation(Ctx ctx, BinaryOperation node);
  Ctx visitBullseyeFunction(Ctx ctx, BullseyeFunction node); 
  Ctx visitAwait(Ctx ctx, Await node);
  Ctx visitIOBind(Ctx ctx, IOBind node);
  Ctx visitWrapPureInIO(Ctx ctx, WrapPureInIO node);
  Ctx visitClassInit(Ctx ctx, ClassInit node);
  Ctx visitTaggedSumInit(Ctx ctx, TaggedSumInit node);
  Ctx visitGetSymbol(Ctx ctx, GetSymbol node);
  Ctx visitSetSymbol(Ctx ctx, SetSymbol node);
}
