import 'type.dart';
import 'type_provider.dart';
import 'value.dart';
import 'value_visitor.dart';

abstract class BullseyeFunction extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitBullseyeFunction(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

class NamedFunction extends BullseyeFunction {}

class AnonymousFunction extends BullseyeFunction {}

class FunctionRef extends BullseyeFunction {}

