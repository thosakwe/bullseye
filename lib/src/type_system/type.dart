import 'package:analyzer/dart/element/type.dart' as dart;

abstract class BullseyeType {
  bool isChildOf(BullseyeType other) => isIdenticalTo(other);

  bool isIdenticalTo(BullseyeType other) => this == other;
}

class IntType extends BullseyeType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is IntType;
}

class StringType extends BullseyeType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is StringType;
}

class BoolType extends BullseyeType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is BoolType;
}

class DoubleType extends BullseyeType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is DoubleType;
}

class ListType extends BullseyeType {
  final BullseyeType innerType;
  ListType(this.innerType);
}

class TupleType extends BullseyeType {
  final List<BullseyeType> items;
  TupleType(this.items);
}

class RecordType extends BullseyeType {
  final Map<String, BullseyeType> fields;
  RecordType(this.fields);
}

class AliasedType extends BullseyeType {
  final String name;
  final BullseyeType reference;
  AliasedType(this.name, this.reference);

  @override
  bool isIdenticalTo(BullseyeType other) => reference.isIdenticalTo(other);
}

class WrappedDartClass extends BullseyeType {
  final dart.InterfaceType clazz;

  WrappedDartClass(this.clazz);
}
