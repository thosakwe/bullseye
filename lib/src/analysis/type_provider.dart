import 'type.dart';

class TypeProvider {
  final BoolType boolType = BoolType();
  final DoubleType doubleType = DoubleType();
  final IOType ioUnitType = IOType(UnitType());
  final IntType intType = IntType();
  final StringType stringType = StringType();
  final UnitType unitType = UnitType();

  PolymorphicType get eitherType => _eitherType;
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
