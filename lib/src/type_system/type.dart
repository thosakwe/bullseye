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

class UnitType extends BullseyeType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is UnitType;
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

class TypeParameter extends BullseyeType {
  final String name;
  // TODO(thosakwe): constraints, i.e. `T extends Int List`...
  TypeParameter(this.name);
}

class PolymorphicType extends BullseyeType {
  final List<TypeParameter> parameters;
  final BullseyeType template;
  PolymorphicType(this.parameters, this.template);
}

class FutureType extends BullseyeType {
  final BullseyeType inner;
  FutureType(this.inner);
}

class IOType extends BullseyeType {
  final BullseyeType inner;
  IOType(this.inner);
}

class TaggedSumType extends BullseyeType {
  final List<TypeConstructor> constructors;
  TaggedSumType(this.constructors);
}

class TypeConstructor {
  final String name;
  final List<BullseyeType> parameters;
  TypeConstructor(this.name, this.parameters);
}

class WrappedDartClass extends BullseyeType {
  final dart.InterfaceType clazz;

  WrappedDartClass(this.clazz);
}
