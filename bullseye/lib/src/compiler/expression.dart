import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:source_span/source_span.dart';
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelExpressionCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelExpressionCompiler(this.compiler);

  k.Expression compile(Expression ctx, SymbolTable<k.Expression> scope) {
    if (ctx is Literal) return compileLiteral(ctx, scope);
    if (ctx is Identifier) return compileIdentifier(ctx, scope);
    if (ctx is BinaryExpression) return compileBinary(ctx, scope);
    if (ctx is NamedCallExpression) return compileNamedCall(ctx, scope);
    if (ctx is MemberCallExpression) return compileMemberCall(ctx, scope);
    compiler.exceptions.add(new BullseyeException(
        BullseyeExceptionSeverity.error,
        ctx.span,
        'Cannot compile expression $ctx'));
    return null;
  }

  k.Expression compileLiteral(Literal ctx, SymbolTable<k.Expression> scope) {
    if (ctx is NullLiteral) {
      return new k.NullLiteral();
    } else if (ctx is NumberLiteral<int>) {
      return new k.IntLiteral(ctx.constantValue);
    } else if (ctx is NumberLiteral<double>) {
      return new k.DoubleLiteral(ctx.constantValue);
    } else if (ctx is BoolLiteral) {
      return new k.BoolLiteral(ctx.constantValue);
    } else if (ctx is StringLiteral) {
      if (ctx.hasConstantValue) {
        return new k.StringLiteral(ctx.constantValue);
      } else {
        var parts = <k.Expression>[];

        for (var part in ctx.parts) {
          if (part is TextStringPart) {
            parts.add(new k.StringLiteral(part.text));
          } else if (part is InterpolationStringPart) {
            parts.add(compile(part.expression, scope));
          } else {
            throw new UnsupportedError(
                'Unsupported string part $part in compiler');
          }
        }

        return new k.StringConcatenation(parts);
      }
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

  k.Arguments compileArguments(
      CallExpression ctx, SymbolTable<k.Expression> scope) {
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

    return new k.Arguments(positional, named: named);
  }

  k.InterfaceType resolveTargetToType(k.Expression targetExpr, FileSpan span) {
    // Next, just determine if we are calling a function, or instantiating a class.
    var targetType = targetExpr.getStaticType(compiler.types);
    var typeOfType = compiler.coreTypes.typeClass;
    k.InterfaceType interfaceType;

    // If this is a type wrapper, handle it.
    if (targetExpr is TypeWrapper) {
      if (targetExpr.clazz != null) {
        interfaceType = targetExpr.clazz.thisType;
      } else {
        compiler.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            span,
            "$interfaceType is a typedef, and therefore cannot be instantiated."));
        return null;
      }
    } else {
      // Check if the expression is an instance of Type.
      if (targetType is k.InterfaceType &&
          compiler.classHierarchy
              .isSubclassOf(targetType.classNode, typeOfType)) {
        interfaceType = targetType;
      }
    }

    return interfaceType;
  }

  /// Try to infer the types of any ParameterGet instances being passed as function arguments.
  void inferArgumentTypes(k.Arguments args, k.FunctionNode function) {
    int i = 0;

    void infer(k.Expression expr, k.VariableDeclaration param) {
      if (expr is ParameterGet) {
        expr.type = param.type;
      }
    }

    for (var arg in args.positional) {
      try {
        var param = function.positionalParameters[i++];
        infer(arg, param);
      } on RangeError {
        // Ignore...
      }
    }

    i = 0;

    for (var arg in args.named) {
      try {
        var param = function.namedParameters[i++];
        infer(arg.value, param);
      } on RangeError {
        // Ignore...
      }
    }
  }

  k.Expression compileCallInvocation(
      k.Expression targetExpr,
      k.InterfaceType interfaceType,
      k.Arguments args,
      FileSpan span,
      String constructorName,
      k.Procedure knownProcedure) {
    if (interfaceType != null) {
      var constructor = interfaceType.classNode.constructors.firstWhere(
          (c) => c.name.name == constructorName,
          orElse: () => null);

      if (constructor == null) {
        var type = constructorName.isEmpty
            ? 'default constructor'
            : "constructor named '$constructorName'";
        compiler.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            span,
            "$interfaceType has no $type, and therefore cannot be instantiated."));
        return null;
      }

      inferArgumentTypes(args, constructor.function);
      return new k.ConstructorInvocation(constructor, args);
    } else if (knownProcedure == null) {
      // Otherwise, just return a call.
      // If knownProcedure == null, we are NOT calling a member function.
      var vGet = targetExpr as k.VariableGet;
      var ref = compiler.procedureReferences[vGet];
      if (ref != null) {
        inferArgumentTypes(args, ref.asProcedure.function);
        return new k.StaticInvocation(ref.asProcedure, args);
      } else {
        // TODO: What if it's a variable...? (maybe make a static function for that?)
        compiler.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            span,
            "'${vGet.variable.name}' is not a function, and cannot be invoked."));
        return null;
      }
    } else {
      // We ARE calling a member function.
      inferArgumentTypes(args, knownProcedure.function);
      return new k.MethodInvocation.byReference(
          targetExpr, knownProcedure.name, args, knownProcedure.reference);
    }
  }

  k.Expression compileNamedCall(
      NamedCallExpression ctx, SymbolTable<k.Expression> scope) {
    var targetExpr = scope.resolve(ctx.name.name)?.value;

    if (targetExpr == null) {
      compiler.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          ctx.name.span,
          "The name '${ctx.name.name}' does not exist in this context, and therefore cannot be invoked."));
      return null;
    } else {
      var args = compileArguments(ctx, scope);
      var interfaceType = resolveTargetToType(targetExpr, ctx.name.span);
      return compileCallInvocation(
          targetExpr, interfaceType, args, ctx.name.span, '', null);
    }
  }

  k.Expression compileMemberCall(
      MemberCallExpression ctx, SymbolTable<k.Expression> scope) {
    var object = compile(ctx.target.object, scope);

    if (object == null) {
      return null;
    } else {
      var interfaceType = resolveTargetToType(object, ctx.target.span);
      k.Procedure knownProcedure;

      if (interfaceType == null) {
        // Check if the member exists
        var clazz = object.getStaticType(compiler.types);

        if (clazz is k.InterfaceType) {
          while (clazz != null) {
            var c = clazz as k.InterfaceType;
            var it = c.className.asClass;
            knownProcedure = it.procedures.firstWhere(
                (p) => p.name.name == ctx.target.name.name,
                orElse: () => null);
            if (knownProcedure != null) break;
            clazz = it.superclass.thisType;
          }
        }

        if (knownProcedure == null) {
          var type = object.getStaticType(compiler.types);
          compiler.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              ctx.target.span,
              "$type has no getter named '${ctx.target.name.name}'."));
          return null;
        }
      }

      var args = compileArguments(ctx, scope);
      return compileCallInvocation(object, interfaceType, args, ctx.target.span,
          ctx.target.name.name, knownProcedure);
    }
  }
}
