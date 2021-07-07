import 'type.dart';
import 'type_provider.dart';
import 'value.dart';

abstract class BullseyeSymbol {
  String get name;
  BullseyeType getType(TypeProvider typeProvider);
}

// TODO(thosakwe): types, constructors, modules(?), etc.

/// A function parameter...
class Parameter extends BullseyeSymbol {
  final String name;
  final BullseyeType type;
  final BullseyeValue? defaultsTo;
  Parameter(this.name, this.type, this.defaultsTo);

  @override
  BullseyeType getType(TypeProvider typeProvider) => type;
}
