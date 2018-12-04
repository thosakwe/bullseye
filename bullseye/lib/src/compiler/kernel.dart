import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelCompiler {
  final List<BullseyeException> exceptions = [];
  final List<k.Library> libraries = [];
  final CompilationUnit compilationUnit;
  SymbolTable<k.Expression> scope = new SymbolTable();
  bool _compiled = false;

  BullseyeKernelCompiler(this.compilationUnit);

  k.Component toComponent() {
    compile();
    return new k.Component(libraries: libraries);
  }

  void compile() {
    if (!_compiled) {
      for (var decl in compilationUnit.topLevelDeclarations) {
        if (decl is FunctionDeclaration) {}
      }

      _compiled = true;
    }
  }

  k.FunctionDeclaration compileFunctionDeclaration(FunctionDeclaration ctx) {
    var variable = new k.VariableDeclaration(ctx.name.name);
    var function = compileFunctionBody(ctx.parameterList.parameters,
        ctx.body.letBindings, ctx.body.returnValue);
    return new k.FunctionDeclaration(variable, function);
  }

  k.FunctionNode compileFunctionBody(List<Parameter> parameters,
      Iterable<LetBinding> letBindings, Expression returnValue) {
    var body = <k.Statement>[];
    var positional = <k.VariableDeclaration>[];
    var named = <k.VariableDeclaration>[];
    var requiredCount = 0;
    // TODO: Async
    // TODO: Return type

    return new k.FunctionNode(new k.Block(body),
        positionalParameters: positional,
        namedParameters: named,
        requiredParameterCount: requiredCount);
  }
}
