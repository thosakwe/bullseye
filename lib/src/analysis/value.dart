import 'package:bullseye_lang/src/analysis/symbol.dart';

import 'type.dart';
import 'type_provider.dart';

abstract class BullseyeValue {
  Object? get constantValue => null;

  BullseyeType getType(TypeProvider typeProvider);

  BullseyeValue? cast(BullseyeType to, TypeProvider typeProvider) =>
      getType(typeProvider).castValue(this, to);
}

class ConstInt extends BullseyeValue {
  final int value;

  ConstInt(this.value);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.intType;
}

class ConstDouble extends BullseyeValue {
  final double value;

  ConstDouble(this.value);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.doubleType;
}

class ConstString extends BullseyeValue {
  final String value;

  ConstString(this.value);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.stringType;
}

class ConstBool extends BullseyeValue {
  final bool value;

  ConstBool(this.value);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.boolType;
}

class ConstUnit extends BullseyeValue {
  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.unitType;
}

// TODO(thosakwe): Allow const tuples...
class Tuple extends BullseyeValue {
  final List<BullseyeValue> items;

  Tuple(this.items);

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
}

abstract class FunctionCall extends BullseyeValue {
  final List<BullseyeValue> positionalArguments;
  final Map<String, BullseyeValue> namedArguments;
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
}

class BinaryOperation extends BullseyeValue {
}

abstract class BullseyeFunction extends BullseyeValue {
}

class NamedFunction extends BullseyeFunction {
}

class AnonymousFunction extends BullseyeFunction {
}

class FunctionRef extends BullseyeFunction {
}

class Await extends BullseyeValue {
}

class IOBind extends BullseyeValue {
}

class IOAction extends BullseyeValue {
}

class ClassInit extends BullseyeValue {
}

class TaggedSumInit extends BullseyeValue {
}

class AnonymousFunction extends BullseyeValue {
}

class GetSymbol extends BullseyeValue {
  final BullseyeSymbol symbol;
}

// // TODO(thosakwe): Allow const tuples...
// class Record extends BullseyeValue {
//   final Map<String, BullseyeValue> items;

//   Record(this.items);

//   @override
//   BullseyeType getType(TypeProvider typeProvider) => RecordType(
//       items.map((key, value) => MapEntry(key, value.getType(typeProvider))));
// }
