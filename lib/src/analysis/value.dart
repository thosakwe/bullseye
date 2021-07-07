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

// // TODO(thosakwe): Allow const tuples...
// class Record extends BullseyeValue {
//   final Map<String, BullseyeValue> items;

//   Record(this.items);

//   @override
//   BullseyeType getType(TypeProvider typeProvider) => RecordType(
//       items.map((key, value) => MapEntry(key, value.getType(typeProvider))));
// }

// TODO(thosakwe): Get ref, get param, set symbol, if/then, function call, curry
// function, let ... in, arithmetic/bitwise, IOBind, IOAction, await, anonymous
// function, constructor initialization
