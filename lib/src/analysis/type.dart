import 'package:analyzer/dart/element/type.dart' as dart;
import 'value.dart';

/// A Bullseye type.
///
/// Bullseye types do not always map directly to Dart types. Some types, like
/// TupleType or RecordType, do not exist in the Dart type system at the time of
/// this writing.
abstract class BullseyeType {
  /// Casts a value of this type [to] another.
  /// If `null` is returned, it means that values of this type are not
  /// compatible with the target type.
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

/// Alias for [List].
class ListType extends BullseyeType {
  final BullseyeType innerType;
  ListType(this.innerType);
}

/// A type for tuples containing the provided [fields].
///
/// Ex. `{ one = 1; two = "two"; }` has the type `{ one: int; two: string; }`.
class RecordType extends BullseyeType {
  final Map<String, BullseyeType> fields;
  RecordType(this.fields);
}

/// A type for tuples containing the provided [items].
/// "Tuple" types are syntactic sugar in Bullseye.
/// TODO(thosakwe): Doesn't this mean TupleType should be completely removed,
/// then?
///
/// Ex. `(2, "3", 4.0)` has the type `int * string * double`.
class TupleType extends BullseyeType {
  final List<BullseyeType> items;
  TupleType(this.items);
}

/// An alias for another type. In practice, most user-defined types will fall
/// under this category.
class AliasedType extends BullseyeType {
  final String name;
  final BullseyeType reference;
  AliasedType(this.name, this.reference);

  @override
  bool isIdenticalTo(BullseyeType other) => reference.isIdenticalTo(other);
}

/// Carries information about a parameter to a polymorphic type.
class TypeParameter extends BullseyeType {
  final String name;
  // TODO(thosakwe): constraints, i.e. `T extends Int List`...
  TypeParameter(this.name);
}

/// A function that takes one or more types as arguments, and then returns a
/// type.
class PolymorphicType extends BullseyeType {
  final List<TypeParameter> parameters;
  final BullseyeType template;
  PolymorphicType(this.parameters, this.template);
}

/// Alias for [Future].
class FutureType extends BullseyeType {
  final BullseyeType inner;
  FutureType(this.inner);
}

/// A type returned by functions that describe side effects.
/// Values of this type tell the compiler what to do, without caring when it
/// gets done, if it even gets done at all.
class IOType extends BullseyeType {
  final BullseyeType inner;
  IOType(this.inner);
}

/// A sum type, where every variant has a name.
class TaggedSumType extends BullseyeType {
  final List<TypeConstructor> constructors;
  TaggedSumType(this.constructors);
}

/// A function that initializes a value of a given type.
/// This includes the constructors of [WrappedDartClass]es.
class TypeConstructor {
  final String name;
  final List<BullseyeType> parameters;
  TypeConstructor(this.name, this.parameters);
}

/// An alias for the given [dartClass].
class WrappedDartClass extends BullseyeType {
  final dart.InterfaceType dartClass;

  WrappedDartClass(this.dartClass);
}
