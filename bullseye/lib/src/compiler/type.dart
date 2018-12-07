import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelTypeCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelTypeCompiler(this.compiler);

  k.DartType compile(TypeNode ctx, SymbolTable<k.Expression> scope) {
    if (ctx is NamedType) return compileNamed(ctx, scope);
    compiler.exceptions.add(new BullseyeException(
        BullseyeExceptionSeverity.error, ctx.span, 'Cannot compile type $ctx'));
    return null;
  }

  k.DartType compileNamed(NamedType ctx, SymbolTable<k.Expression> scope) {
    // TODO: Library imports
    var value = scope.resolve(ctx.name.name)?.value;

    if (value == null) {
      compiler.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          ctx.span,
          "The name '${ctx.name.name}' does not exist in this context."));
      return null;
    } else if (value is TypeWrapper) {
      return value.type;
    } else {
      compiler.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          ctx.span,
          "Instance of '${value.getStaticType(compiler.types)}' is not a type."));
      return null;
    }
  }
}
