import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;

class BullseyeKernelExpressionCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelExpressionCompiler(this.compiler);

  k.Expression compile(Expression ctx) {
    if (ctx is Literal) return compileLiteral(ctx);

    throw new UnsupportedError('Cannot compile expression $ctx');
  }

  k.Expression compileLiteral(Literal ctx) {
    if (ctx is NullLiteral) {
      return new k.NullLiteral();
    } else if (ctx is NumberLiteral<int>) {
      return new k.IntLiteral(ctx.constantValue);
    } else if (ctx is NumberLiteral<double>) {
      return new k.DoubleLiteral(ctx.constantValue);
    } else if (ctx is BoolLiteral) {
      return new k.BoolLiteral(ctx.constantValue);
    }

    throw new UnsupportedError('Cannot compile literal $ctx');
  }
}
