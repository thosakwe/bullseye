import 'package:bullseye_lang/src/analysis/symbol.dart';

import 'type.dart';
import 'type_provider.dart';
import 'value_visitor.dart';

abstract class BullseyeValue {
  Object? get constantValue => null;

  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor);
  BullseyeType getType(TypeProvider typeProvider);

  BullseyeValue? cast(BullseyeType to, TypeProvider typeProvider) =>
      getType(typeProvider).castValue(this, to);
}

class ConstInt extends BullseyeValue {
  final int value;

  ConstInt(this.value);

  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitConstInt(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.intType;
}

class ConstDouble extends BullseyeValue {
  final double value;

  ConstDouble(this.value);

  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitConstDouble(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.doubleType;
}

class ConstString extends BullseyeValue {
  final String value;

  ConstString(this.value);

  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitConstString(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.stringType;
}

class ConstBool extends BullseyeValue {
  final bool value;

  ConstBool(this.value);

  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitConstBool(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.boolType;
}

class ConstUnit extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitConstUnit(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.unitType;
}

// TODO(thosakwe): Allow const tuples...
class Tuple extends BullseyeValue {
  final List<BullseyeValue> items;

  Tuple(this.items);

  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitTuple(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) =>
      TupleType(items.map((item) => item.getType(typeProvider)).toList());
}

// TODO(thosakwe): Get ref, get param, set symbol, if/then, function call, curry
// function, let ... in, arithmetic/bitwise, IOBind, IOAction, await, anonymous
// function, constructor initialization

class IfThen extends BullseyeValue {
  final BullseyeValue condition;
  final BullseyeValue ifTrue;
  final BullseyeValue ifFalse;
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitIfThen(ctx, this);

}

abstract class FunctionCall extends BullseyeValue {
  final List<BullseyeValue> positionalArguments;
  final Map<String, BullseyeValue> namedArguments;
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitFunctionCall(ctx, this);

}

class DirectCall extends FunctionCall {
  final Symbol target;
}

class IndirectCall extends FunctionCall {
  final BullseyeValue target;
}

class PartialCall extends BullseyeValue {
  final BullseyeValue target;
}

class LetIn extends BullseyeValue {
  final String name;
  final BullseyeValue value;
  final BullseyeValue body;
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitLetIn(ctx, this);

}

class BinaryOperation extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitBinaryOperation(ctx, this);

}

abstract class BullseyeFunction extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitBullseyeFunction(ctx, this);

}

class NamedFunction extends BullseyeFunction {
}

class AnonymousFunction extends BullseyeFunction {
}

class FunctionRef extends BullseyeFunction {
}

class Await extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitAwait(ctx, this);

}

class IOBind extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitIOBind(ctx, this);

}

/// Wraps a pure value in an IO...
class WrapPureInIO extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitWrapPureInIO(ctx, this);

}

class ClassInit extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitClassInit(ctx, this);

}

class TaggedSumInit extends BullseyeValue {
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitTaggedSumInit(ctx, this);

}

class GetSymbol extends BullseyeValue {
  final BullseyeSymbol symbol;
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitGetSymbol(ctx, this);

}

class SetSymbol extends BullseyeValue {
  final BullseyeSymbol symbol;
  @override
  Ctx accept<Ctx, T>(Ctx ctx, ValueVisitor<Ctx, T> visitor) => visitor.visitSetSymbol(ctx, this);

}
// // TODO(thosakwe): Allow const tuples...
// class Record extends BullseyeValue {
//   final Map<String, BullseyeValue> items;

//   Record(this.items);

//   @override
//   BullseyeType getType(TypeProvider typeProvider) => RecordType(
//       items.map((key, value) => MapEntry(key, value.getType(typeProvider))));
// }
