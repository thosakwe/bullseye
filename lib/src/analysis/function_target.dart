import 'function_target_visitor.dart';
import 'value.dart';

abstract class FunctionTarget {
  T accept<T>(FunctionTargetVisitor<T> visitor);
}

class DirectTarget extends FunctionTarget {
  final Symbol target;

  DirectTarget(this.target);

  T accept<T>(FunctionTargetVisitor<T> visitor) =>
      visitor.visitDirectTarget(this);
}

class IndirectTarget extends FunctionTarget {
  final BullseyeValue target;

  IndirectTarget(this.target);

  T accept<T>(FunctionTargetVisitor<T> visitor) =>
      visitor.visitIndirectTarget(this);
}

class PartialTarget extends FunctionTarget {
  final BullseyeValue target;

  PartialTarget(this.target);

  T accept<T>(FunctionTargetVisitor<T> visitor) =>
      visitor.visitPartialTarget(this);
}

class Constructor extends FunctionTarget {
  T accept<T>(FunctionTargetVisitor<T> visitor) =>
      visitor.visitConstructor(this);
}

