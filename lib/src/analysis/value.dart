import 'package:bullseye_lang/src/analysis/symbol.dart';

import 'function_call_visitor.dart';
import 'function_target.dart';
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

  /// See [accept].
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor);

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
  ConstInt(int value) : super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstInt(this);

  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitConstInt(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.intType;
}

/// A constant [double].
class ConstDouble extends Constant<double> {
  ConstDouble(double value) : super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstDouble(this);

  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitConstDouble(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.doubleType;
}

/// A constant [String].
class ConstString extends Constant<String> {
  ConstString(String value) : super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstString(this);

  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitConstString(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.stringType;
}

/// A constant [bool].
class ConstBool extends Constant<bool> {
  ConstBool(bool value) : super(value);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstBool(this);

  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitConstBool(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => typeProvider.boolType;
}

/// The single value belonging to the [UnitType].
class ConstUnit extends Constant<Null> {
  ConstUnit() : super(null);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitConstUnit(this);

  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitConstUnit(ctx, this);

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
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitTuple(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) =>
      TupleType(items.map((item) => item.getType(typeProvider)).toList());
}

// TODO(thosakwe): Get ref, get param, set symbol, if/then, function call, curry
// function, let ... in, arithmetic/bitwise, IOBind, IOAction, await, anonymous
// function, constructor initialization

/// A choice between two values, based on some [condition].
/// `condition ? whenTrue : whenFalse`.
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
  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitIfThen(ctx, this);
}

/// A value obtained as the result of invoking some function with the provided
/// arguments.
///
/// The [target] is not necessarily a Dart function; it may be a reference to a
/// Dart constructor.
abstract class FunctionCall extends BullseyeValue {
  final FunctionTarget target;
  final List<BullseyeValue> positionalArguments;
  final Map<String, BullseyeValue> namedArguments;

  FunctionCall(this.target, this.positionalArguments, this.namedArguments);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitFunctionCall(this);
  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitFunctionCall(ctx, this);
}

/// Evaluates [body] in a new context (where [name] = [value]).
/// This is most similar to setting a variable in an imperative language, and
/// then immediately returning an expression that references that variable.
///
/// For example: `let x = 2 in x * 2` is equivalent to this Dart code:
///
/// ```dart
/// var x = 2;
/// return x * 2;
/// ```
class LetIn extends BullseyeValue {
  final String name;
  final BullseyeValue value;
  final BullseyeValue body;

  LetIn(this.name, this.value, this.body);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitLetIn(this);
  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitLetIn(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => body.getType(typeProvider);
}

/// A value which is obtained by performing a binary operation on two values.
/// TODO(thosakwe): Flesh this class out.
class BinaryOperation extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitBinaryOperation(this);
  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitBinaryOperation(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

/// A value obtained by awaiting the provided [future].
/// TODO(thosakwe): Flesh this class out.
class Await extends BullseyeValue {
  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitAwait(this);
  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitAwait(ctx, this);

  @override
  BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

abstract class IOValue {}

abstract class IOVisitor<T> {}

class IOBind extends IOValue {
  // @override
  // T accept<T>(ValueVisitor<T> visitor) => visitor.visitIOBind(this);

  // @override
  // BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

/// Wraps a pure value in an IO...
/// TODO(thosakwe): Flesh this class out.
class WrapPureInIO extends IOValue {
  // @override
  // T accept<T>(ValueVisitor<T> visitor) => visitor.visitWrapPureInIO(this);

  // @override
  // BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

class SetSymbol extends IOValue {
  final BullseyeSymbol symbol;
  final BullseyeValue value;

  SetSymbol(this.symbol, this.value);

  // @override
  // T accept<T>(ValueVisitor<T> visitor) => visitor.visitSetSymbol(this);

  // @override
  // BullseyeType getType(TypeProvider typeProvider) => throw UnimplementedError();
}

/// A value obtained by fetching the value of the given [symbol] at runtime.
class GetSymbol extends BullseyeValue {
  final BullseyeSymbol symbol;

  GetSymbol(this.symbol);

  @override
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitGetSymbol(this);

  @override
  T acceptArg1<Ctx, T>(Ctx ctx, ValueVisitorArg1<Ctx, T> visitor) =>
      visitor.visitGetSymbol(ctx, this);

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
