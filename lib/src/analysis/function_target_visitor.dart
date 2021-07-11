import 'value.dart';

abstract class FunctionTargetVisitor<T> {
  T visitDirectTarget(DirectTarget node);
  T visitIndirectTarget(IndirectTarget node);
  T visitPartialTarget(PartialTarget node);
  T visitConstructor(Constructor node);
}
