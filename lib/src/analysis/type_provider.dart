import 'type.dart';

/// A class that manages singletons of common Bullseye types.
class TypeProvider {
  /// The `bool type.
  final BoolType boolType = BoolType();

  /// The `double type.
  final DoubleType doubleType = DoubleType();

  /// The `IO ()` type.
  final IOType ioUnitType = IOType(UnitType());

  /// The `int` type.
  final IntType intType = IntType();

  /// The `String` type.
  final StringType stringType = StringType();

  /// The `()` type.
  final UnitType unitType = UnitType();

  /// The `Either` type.
  PolymorphicType get eitherType => _eitherType;

  /// The `Maybe` type.
  PolymorphicType get maybeType => _maybeType;

  late PolymorphicType _eitherType, _maybeType;

  TypeProvider() {
    _eitherType = PolymorphicType(
      [TypeParameter('l'), TypeParameter('r')],
      TaggedSumType([
        TypeConstructor('Just', [TypeParameter('a')]),
        TypeConstructor('Nothing', [])
      ]),
    );
    _maybeType = PolymorphicType(
      [TypeParameter('a')],
      TaggedSumType([
        TypeConstructor('Just', [TypeParameter('a')]),
        TypeConstructor('Nothing', [])
      ]),
    );
  }
}
