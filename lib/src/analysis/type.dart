import 'package:analyzer/dart/element/type.dart' as dart;
import 'value.dart';

/// A Bullseye type.
///
/// Bullseye types do not always map directly to Dart types. Some types, like
/// TupleType or RecordType, do not exist in the Dart type system at the time of
/// this writing.
abstract class BullseyeType {
  BullseyeValue? castValue(BullseyeValue value, BullseyeType to);
  bool isIdenticalTo(BullseyeType other) => this == other;
}

/// Base class for primitive types.
///
/// TODO(thosakwe): Eventually, primitive types may carry more specific
/// information.
abstract class PrimitiveType implements BullseyeType {
  BullseyeValue? castValue(BullseyeValue value, BullseyeType to) {
    if (isIdenticalTo(to)) {
      return value;
    } else {
      return null;
    }
  }
}

/// Alias for [int].
class IntType extends BullseyeType with PrimitiveType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is IntType;
}

/// Alias for [String].
class StringType extends BullseyeType with PrimitiveType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is StringType;
}

/// A type representing a set that has exactly one value.
///
/// In practice, it doesn't matter which Dart type this maps to, so Bullseye's
/// unit type compiles to [Null].
class UnitType extends BullseyeType with PrimitiveType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is UnitType;
}

/// Alias for [bool].
class BoolType extends BullseyeType with PrimitiveType {
  @override
  bool isIdenticalTo(BullseyeType other) => other is BoolType;
}

/// Alias for [double].
class DoubleType extends BullseyeType with PrimitiveType {
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

// class RecordType extends BullseyeType {
//   final Map<String, BullseyeType> fields;
//   RecordType(this.fields);
// }

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
