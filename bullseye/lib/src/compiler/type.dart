import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;

class BullseyeKernelTypeCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelTypeCompiler(this.compiler);

  k.DartType compile(TypeNode ctx) {
    compiler.exceptions.add(new BullseyeException(
        BullseyeExceptionSeverity.error, ctx.span, 'Cannot compile type $ctx'));
    return null;
  }
}
