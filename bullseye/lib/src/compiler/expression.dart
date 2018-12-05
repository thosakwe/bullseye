import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelExpressionCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelExpressionCompiler(this.compiler);

  k.Expression compile(Expression ctx, SymbolTable<k.Expression> scope) {
    if (ctx is Literal) return compileLiteral(ctx);
    if (ctx is Identifier) return compileIdentifier(ctx, scope);
    if (ctx is BinaryExpression) return compileBinary(ctx, scope);
    if (ctx is NamedCallExpression) return compileNamedCall(ctx, scope);
    compiler.exceptions.add(new BullseyeException(
        BullseyeExceptionSeverity.error,
        ctx.span,
        'Cannot compile expression $ctx'));
    return null;
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

    compiler.exceptions.add(new BullseyeException(
        BullseyeExceptionSeverity.error,
        ctx.span,
        'Cannot compile literal $ctx'));
    return null;
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

  k.Expression compileBinary(
      BinaryExpression ctx, SymbolTable<k.Expression> scope) {
    var left = compile(ctx.left, scope);
    if (left == null) return null;
    var right = compile(ctx.right, scope);
    if (right == null) return null;
    var op = ctx.op.span.text;
    var leftType = left.getStaticType(compiler.types);
    var rightType = right.getStaticType(compiler.types);

    // Try to apply a type to dynamic parameters
    if (left is ParameterGet && left.isDynamic) {
      left.type = leftType = rightType;
    }

    if (right is ParameterGet && right.isDynamic) {
      right.type = rightType = leftType;
    }

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

  k.Expression compileNamedCall(
      NamedCallExpression ctx, SymbolTable<k.Expression> scope) {
    var targetExpr = scope.resolve(ctx.name.name)?.value;

    if (targetExpr == null) {
      compiler.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          ctx.name.span,
          "The name '${ctx.name.name}' does not exist in this context."));
      return null;
    } else {
      var positional = <k.Expression>[];
      var named = <k.NamedExpression>[];
      for (var arg in ctx.arguments) {
        var value = compile(arg.expression, scope);
        if (value == null) return null;
        if (arg is NamedArgument) {
          named.add(new k.NamedExpression(arg.name.name, value));
        } else {
          positional.add(value);
        }
      }

      var args = new k.Arguments(positional, named: named);

      // Next, just determine if we are calling a function, or instantiating a class.
      var targetType = targetExpr.getStaticType(compiler.types);
      var typeOfType = compiler.coreTypes.typeClass;
      k.InterfaceType interfaceType;

      // Check if the expression is an instance of Type.
      if (targetType is k.InterfaceType &&
          compiler.classHierarchy
              .isSubclassOf(targetType.classNode, typeOfType)) {
        interfaceType = targetType;
      }

      if (interfaceType != null) {
        var constructor = interfaceType.classNode.constructors
            .firstWhere((c) => c.name.name.isEmpty, orElse: () => null);

        if (constructor == null) {
          compiler.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              ctx.name.span,
              "$interfaceType has no default constructor, and therefore cannot be instantiated."));
          return null;
        }
        return new k.ConstructorInvocation(constructor, args);
      } else {
        // Otherwise, just return a call.
        var vGet = targetExpr as k.VariableGet;
        var ref = compiler.procedureReferences[vGet];
        if (ref != null) {
          return new k.StaticInvocation(ref.asProcedure, args);
        } else {
          // TODO: What if it's a variable...? (maybe make a static function for that?)
          compiler.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              ctx.name.span,
              "'${ctx.name.name}' is not a function, and cannot be invoked."));
          return null;
        }
      }
    }
  }
}
