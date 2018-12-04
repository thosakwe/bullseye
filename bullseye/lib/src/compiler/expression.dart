import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelExpressionCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelExpressionCompiler(this.compiler);

  k.Expression compile(Expression ctx, SymbolTable<k.Expression> scope) {
    if (ctx is Literal) return compileLiteral(ctx);

    if (ctx is Identifier) {
      var symbol = scope.resolve(ctx.name);

      if (symbol != null) {
        return symbol.value;
      } else {
        compiler.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            ctx.span,
            "The name '${ctx.name}' does not exist in this context."));
        return null;
      }
    }

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
