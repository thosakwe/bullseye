import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelExpressionCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelExpressionCompiler(this.compiler);

  k.Expression compile(Expression ctx, SymbolTable<k.Expression> scope) {
    if (ctx is Literal) return compileLiteral(ctx);
    if (ctx is Identifier) return compileIdentifier(ctx, scope);
    if (ctx is AddSubExpression) return compileAddSub(ctx, scope);
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

  k.Expression compileIdentifier(
      Identifier ctx, SymbolTable<k.Expression> scope) {
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

  k.Expression compileAddSub(
      AddSubExpression ctx, SymbolTable<k.Expression> scope) {
    var left = compile(ctx.left, scope);
    if (left == null) return null;
    var right = compile(ctx.right, scope);
    if (right == null) return null;
    var op = ctx.op.span.text;
    var leftType = left.getStaticType(compiler.types);
    var rightType = right.getStaticType(compiler.types);

    if (leftType is k.InterfaceType) {
      var clazz = leftType.className.asClass;
      k.Procedure member;

      while (clazz != null) {
        member = clazz.procedures
            .firstWhere((m) => m.name.name == op, orElse: () => null);
        if (member != null) break;
        clazz = clazz.superclass;
      }

      if (member != null) {
        var name = new k.Name(op);
        var args = new k.Arguments([right]);
        return new k.MethodInvocation(left, name, args, member);
      } else {
        compiler.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            ctx.op.span,
            "The operator '$op' is not defined for $leftType."));
        return null;
      }
    } else {
      compiler.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          ctx.op.span,
          "Cannot apply the operator '$op' to $leftType and $rightType."));
      return null;
    }
  }
}
