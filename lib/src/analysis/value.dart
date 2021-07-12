import 'package:bullseye_lang/src/analysis/symbol.dart';

import 'function_call_visitor.dart';
import 'function_target_visitor.dart';
import 'function_visitor.dart';
import 'type.dart';
import 'type_provider.dart';
import 'value_visitor.dart';

/// Represents either a constant value, or some operation which produces a value
/// at runtime.
///
/// All values have an associated type. See [BullseyeType] for more information.
abstract class BullseyeValue {
  /// The constant value, if any, as a Dart runtime object.
  Object? get constantValue => null;

  /// Since Dart does not have sum types at the time of this writing, the
  /// visitor pattern is used. You can use a ValueVisitor to perform any sort of
  /// computation over a value; in fact, the compiler extends ValueVisitor.
  T accept<T>(ValueVisitor<T> visitor);

  /// Returns the value's static type.
  /// A [TypeProvider] is necessary because some types are treated as
  /// singletons.
  BullseyeType getType(TypeProvider typeProvider);

  /// Shorthand for calling [BullseyeType.castValue].
  BullseyeValue? cast(TypeProvider typeProvider, BullseyeType to) =>
      getType(typeProvider).castValue(this, to);
}

/// Base class for constant values, since they share a lot of common properties.
abstract class Constant<T> extends BullseyeValue {
  /// The value.
  final T value;

  Constant(this.value);
}

/// A constant [int].
class ConstInt extends Constant<int> {
  ConstInt(int value):super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstInt(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.intType;
}

/// A constant [double].
class ConstDouble extends Constant<double> {
  ConstDouble(double value):super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstDouble(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.doubleType;
}

/// A constant [String].
class ConstString extends Constant<String> {
  ConstString(String value):super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstString(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.stringType;
}

/// A constant [bool].
class ConstBool extends Constant<bool> {
  ConstBool(bool value):super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstBool(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.boolType;
}

/// The single value belonging to the [UnitType].
class ConstUnit extends Constant<Null> {
  ConstUnit():super(null);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstUnit(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.unitType;
}

// TODO(thosakwe): Allow const tuples...
class Tuple extends BullseyeValue {
  final List<BullseyeValue> items;

  Tuple(this.items);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitTuple(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) =>
      TupleType(items.map((item) => item.getType(typeProvider)).toList());
}

// TODO(thosakwe): Get ref, get param, set symbol, if/then, function call, curry
// function, let ... in, arithmetic/bitwise, IOBind, IOAction, await, anonymous
// function, constructor initialization

class IfThen extends BullseyeValue {
  final BullseyeValue condition;
  final BullseyeValue whenTrue;
  final BullseyeValue whenFalse;

  IfThen(this.condition, this.whenTrue, this.whenFalse);

  @override
  BullseyeType getType(TypeProvider typeProvider) =>
      whenTrue.getType(typeProvider);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitIfThen(this);
}

abstract class FunctionCall extends BullseyeValue {
  final FunctionTarget target;
  final List<BullseyeValue> positionalArguments;
  final Map<String, BullseyeValue> namedArguments;

  FunctionCall(this.target, this.positionalArguments, this.namedArguments);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitFunctionCall(this);

}

abstract class FunctionTarget {
  T accept<T>(FunctionTargetVisitor<T> visitor);
}

class DirectTarget extends FunctionTarget {
  final Symbol target;

  DirectTarget(this.target);

  T accept<T>(FunctionTargetVisitor<T> visitor) => visitor.visitDirectTarget(this);
}

class IndirectTarget extends FunctionTarget {
  final BullseyeValue target;

  IndirectTarget(this.target);

  T accept<T>(FunctionTargetVisitor<T> visitor) => visitor.visitIndirectTarget(this);
}

class PartialTarget extends FunctionTarget {
  final BullseyeValue target;

  PartialTarget(this.target);

  T accept<T>(FunctionTargetVisitor<T> visitor) => visitor.visitPartialTarget(this);
}

class Constructor extends FunctionTarget {
  T accept<T>(FunctionTargetVisitor<T> visitor) => visitor.visitConstructor(this);
}

class LetIn extends BullseyeValue {
  final String name;
  final BullseyeValue value;
  final BullseyeValue body;

  LetIn(this.name, this.value, this.body);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitLetIn(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => body.getType(typeProvider);
}

class BinaryOperation extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitBinaryOperation(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

abstract class BullseyeFunction extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitBullseyeFunction(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

class NamedFunction extends BullseyeFunction {}

class AnonymousFunction extends BullseyeFunction {}

class FunctionRef extends BullseyeFunction {}

class Await extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitAwait(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

class IOBind extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitIOBind(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

/// Wraps a pure value in an IO...
class WrapPureInIO extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitWrapPureInIO(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

class TaggedSumInit extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitTaggedSumInit(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

class GetSymbol extends BullseyeValue {
  final BullseyeSymbol symbol;

  GetSymbol(this.symbol);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitGetSymbol(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

class SetSymbol extends BullseyeValue {
  final BullseyeSymbol symbol;

  SetSymbol(this.symbol);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitSetSymbol(this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}
// // TODO(thosakwe): Allow const tuples...
// class Record extends BullseyeValue {
//   final Map<String, BullseyeValue> items;

//   Record(this.items);

//   @override
//   BullseyeType getType(TypeProvider typeProvider) => RecordType(
//       items.map((key, value) => MapEntry(key, value.getType(typeProvider))));
// }
