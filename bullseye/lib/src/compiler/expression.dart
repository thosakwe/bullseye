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
    if (ctx is MemberExpression) return compileMember(ctx, scope);
    if (ctx is MemberCallExpression) return compileMemberCall(ctx, scope);
    if (ctx is AwaitedExpression) return compileAwaited(ctx, scope);
    if (ctx is BeginEndExpression) return compileBeginEnd(ctx, scope);
    if (ctx is IndirectCallExpression) return compileIndirectCall(ctx, scope);
    if (ctx is FunctionExpression) return compileFunction(ctx, scope);
    if (ctx is ParenthesizedExpression) return compile(ctx.innermost, scope);
    if (ctx is RecordExpression) return compileRecord(ctx, scope);
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
    if (ctx.name == 'null') {
      return k.NullLiteral();
    } else if (ctx.name == 'true') {
      return k.BoolLiteral(true);
    } else if (ctx.name == 'false') {
      return k.BoolLiteral(false);
    }

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

    if (leftType is k.InterfaceType) {
      var clazz = leftType.className.asClass;
      k.Procedure procedure;

      while (clazz != null) {
        procedure = clazz.procedures
            .firstWhere((m) => m.name.name == op, orElse: () => null);
        if (procedure != null) break;
        clazz = clazz.superclass;
      }

      if (procedure != null) {
        var name = new k.Name(op);
        var args = new k.Arguments([right]);
        inferArgumentTypes(args, procedure.function);
        return new k.MethodInvocation(left, name, args, procedure);
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
    //if (args == null) return;
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

        // Look for a factory constructor.
        var factoryProcedure = interfaceType.classNode.procedures.firstWhere(
            (p) => p.isFactory && p.name.name == constructorName,
            orElse: () => null);

        if (factoryProcedure != null) {
          return k.StaticInvocation(factoryProcedure, args);
        } else {
          compiler.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              span,
              "$interfaceType has no $type, and therefore cannot be instantiated."));
          return null;
        }
      } else {
        inferArgumentTypes(args, constructor.function);
        return new k.ConstructorInvocation(constructor, args);
      }
    } else if (knownProcedure == null) {
      // Otherwise, just return a call.
      // If knownProcedure == null, we are NOT calling a member function.
      k.VariableGet vGet;

      if (targetExpr is k.VariableGet) {
        vGet = targetExpr;
      } else if (targetExpr is ParameterGet) {
        vGet = targetExpr.value;
      }

      var ref = compiler.procedureReferences[vGet];
      if (ref != null) {
        inferArgumentTypes(args, ref.asProcedure.function);

        // If this is top-level, return a static invocation
        if (ref.asProcedure.enclosingLibrary != null) {
          return new k.StaticInvocation(ref.asProcedure, args);
        } else {
          // Otherwise, return a method invocation of '.call'
          return new k.MethodInvocation(vGet, new k.Name('call'), args);
        }
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
      if (args == null) return null;
      var interfaceType = resolveTargetToType(targetExpr, ctx.name.span);
      return compileCallInvocation(
          targetExpr, interfaceType, args, ctx.name.span, '', null);
    }
  }

  k.Expression compileMember(
      MemberExpression ctx, SymbolTable<k.Expression> scope) {
    // TODO: super? lib alias?
    var object = compile(ctx.object, scope);

    if (object == null) {
      return null;
    } else {
      var interfaceType = resolveTargetToType(object, ctx.span);

      // If this is a type, it's a static member; return its value.
      if (interfaceType != null) {
        var member = interfaceType.classNode.members.firstWhere(
            (m) => m.name.name == ctx.name.name,
            orElse: () => null);
        if (member != null) {
          return new k.StaticGet(member);
        } else {
          compiler.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              ctx.name.span,
              "$interfaceType has no static getter named '${ctx.name.name}'."));
          return null;
        }
      } else {
        // Resolve the type of the object, to find the getter.
        var typeOf = object.getStaticType(compiler.types);

        if (typeOf is k.InterfaceType) {
          var clazz = typeOf.classNode;

          while (clazz != null) {
            var field = clazz.members.firstWhere(
                (f) {
                  if (f is k.Procedure) {
                    return f.isGetter && f.name.name == ctx.name.name;
                  } else if (f is k.Field) {
                    return f.name.name == ctx.name.name && f.hasImplicitGetter;
                  } else {
                    return false;
                  }
                },
                orElse: () => null);

            if (field != null) {
              return new k.PropertyGet(
                  object, new k.Name(ctx.name.name), field);
            }

            clazz = clazz.superclass;
          }

          compiler.exceptions.add(BullseyeException(
              BullseyeExceptionSeverity.error,
              ctx.name.span,
              "$typeOf has no getter named '${ctx.name.name}'."));
          return null;
          // TODO: Check to see the field exists?
        } else {
          // Otherwise, it's just a property get.
          return new k.PropertyGet(object, new k.Name(ctx.name.name));
        }
      }
    }
  }

  k.Expression compileMemberCall(
      MemberCallExpression ctx, SymbolTable<k.Expression> scope) {
    // TODO: super? lib alias?
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
            clazz = it.superclass?.thisType;
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

  k.Expression compileAwaited(
      AwaitedExpression ctx, SymbolTable<k.Expression> scope) {
    var target = compile(ctx.target, scope);

    if (target != null) {
      return new k.AwaitExpression(target);
    } else {
      // Ostensibly, an error was already reported. Just return null.
      return null;
    }
  }

  k.Expression compileBeginEnd(
      BeginEndExpression ctx, SymbolTable<k.Expression> scope) {
    // TODO: Apply current async marker
    var fnNode = compiler.compileFunctionBody([], ctx.letBindings,
        ctx.ignoredExpressions, ctx.returnValue, k.AsyncMarker.Sync, scope);
    if (fnNode == null) return null;
    var closure = new k.FunctionExpression(fnNode);
    return new k.MethodInvocation(
        closure, new k.Name('call'), new k.Arguments([]));
  }

  k.Expression compileIndirectCall(
      IndirectCallExpression ctx, SymbolTable<k.Expression> scope) {
    // TODO: Make sure it has a call
    var callee = compile(ctx.callee, scope);
    if (callee == null) return null;
    var args = compileArguments(ctx, scope);
    if (args == null) return null;
    return new k.MethodInvocation(callee, new k.Name('call'), args);
  }

  k.Expression compileFunction(
      FunctionExpression ctx, SymbolTable<k.Expression> scope) {
    var fnNode = compiler.compileFunctionBody(
        ctx.parameters, [], [], ctx.returnValue, ctx.asyncMarker, scope);
    if (fnNode == null) return null;
    return new k.FunctionExpression(fnNode);
  }

  k.Expression compileRecord(
      RecordExpression ctx, SymbolTable<k.Expression> scope) {
    if (ctx.withBinding != null) {
      // If this is an { x with ... } expr, then call copyWith(...)
      var withBinding =
          compiler.expressionCompiler.compile(ctx.withBinding, scope);

      if (withBinding == null) {
        return null;
      } else {
        // Dogfooding is the name of the game. Manufacture a MemberCallExpr.
        var target = MemberExpression(
            ctx.comments,
            ctx.span,
            ctx.withBinding,
            Identifier.synthetic([], ctx.span, 'copyWith'),
            Token(TokenType.dot, ctx.span, null));
        var arguments = ctx.pairs.map((pair) {
          return NamedArgument(
              pair.comments, pair.span, pair.identifier, pair.expression);
        }).toList();
        var call =
            MemberCallExpression(ctx.comments, ctx.span, arguments, target);
        return compile(call, scope);
      }
    } else {
      // If it's empty, return `null`.
      if (ctx.pairs.isEmpty) return k.NullLiteral();

      // Otherwise, we need to:
      // 1. Find a type, T, with getters matching the given fields
      // 2: Instantiate T with the fields as named args
      k.DartType type;

      // Query in reverse, so that newer symbols get preference.
      for (var symbol in scope.allVariables.reversed) {
        var value = symbol.value;

        if (value is TypeWrapper && value.clazz != null) {
          var clazz = value.clazz;

          // The class must have the same number of fields, of course.
          if (clazz.fields.length == ctx.pairs.length) {
            // Next, each field must be represented.
            bool found = true;

            for (var field in clazz.fields) {
              var withName = ctx.pairs.where((p) => p.name == field.name.name);
              if (withName.length != 1) {
                // Nope, try the next type.
                found = false;
                break;
              }
            }

            if (!found) continue;

            // We've found our target type!
            type = clazz.thisType;
            break;
          } else {
            continue;
          }
        }
      }

      if (type == null) {
        compiler.exceptions.add(BullseyeException(
            BullseyeExceptionSeverity.error,
            ctx.span,
            'No type in this context matches the signature of this record literal.'));
        return null;
      }

      // Find the default constructor
      k.Member constructor;

      if (type is k.InterfaceType) {
        constructor = type.classNode.members.firstWhere((m) {
          if (m is k.Constructor) {
            return m.name?.name == '';
          } else if (m is k.RedirectingFactoryConstructor) {
          } else if (m is k.Procedure) {
            return m.kind == k.ProcedureKind.Factory && m.name.name == '';
          } else {
            return false;
          }
        }, orElse: () => null);
      }

      if (constructor == null) {
        BullseyeException(BullseyeExceptionSeverity.error, ctx.span,
            "This record literal was mapped to the type '$type', which has no default constructor.");
        return null;
      }

      // Create an arglist
      var args = <k.NamedExpression>[];

      for (var pair in ctx.pairs) {
        var value = compile(pair.expression, scope);

        if (value == null) {
          compiler.exceptions.add(BullseyeException(
              BullseyeExceptionSeverity.error,
              pair.span,
              'Could not compute the value of this expression. Correct the corresponding error.'));
        } else {
          args.add(k.NamedExpression(pair.name, value));
        }
      }

      var arguments = k.Arguments([], named: args);

      if (constructor is k.Constructor) {
        return k.ConstructorInvocation(constructor, arguments);
      } else if (constructor is k.Procedure) {
        return k.StaticInvocation(constructor, arguments);
      } else if (constructor is k.RedirectingFactoryConstructor) {
        var target = constructor.target;

        if (target is k.Constructor) {
          return k.ConstructorInvocation(target, arguments);
        } else if (target is k.Procedure) {
          return k.StaticInvocation(target, arguments);
        } else {
          throw new StateError(
              'Cannot instantiate redirect to $target from $constructor. This is a bug in the compiler; please report it.');
        }
      } else {
        throw new StateError(
            'Cannot instantiate $constructor. This is a bug in the compiler; please report it.');
      }
    }
  }
}
