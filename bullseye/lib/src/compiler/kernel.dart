import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelCompiler {
  final List<BullseyeException> exceptions = [];
  final List<k.Library> libraries = [];
  final CompilationUnit compilationUnit;
  BullseyeKernelExpressionCompiler expressionCompiler;
  k.Library library;
  k.Procedure mainMethod;
  SymbolTable<k.Expression> scope = new SymbolTable();
  bool _compiled = false;

  BullseyeKernelCompiler(this.compilationUnit) {
    expressionCompiler = new BullseyeKernelExpressionCompiler(this);
    library = new k.Library(compilationUnit.span.sourceUrl);
  }

  k.Component toComponent() {
    compile();

    if (mainMethod != null) {
      return new k.Component()..mainMethod = mainMethod;
    } else {
      return new k.Component(libraries: libraries)..mainMethod = mainMethod;
    }
  }

  void compile() {
    if (!_compiled) {
      for (var decl in compilationUnit.topLevelDeclarations) {
        if (decl is FunctionDeclaration) {
          var fn = compileFunctionDeclaration(decl);
          library.addProcedure(fn);
          if (decl.name.name == 'main') mainMethod = fn;
        }
      }

      _compiled = true;
    }
  }

  k.Procedure compileFunctionDeclaration(FunctionDeclaration ctx) {
    var name = new k.Name(ctx.name.name);
    var function = compileFunctionBody(ctx.parameterList.parameters,
        ctx.body.letBindings, ctx.body.returnValue);
    var reference = new k.Reference()
      ..canonicalName = k.CanonicalName.root()
          .getChildFromUri(ctx.span.sourceUrl)
          .getChild(ctx.name.name);
    return new k.Procedure(name, k.ProcedureKind.Method, function,
        reference: reference);
  }

  k.FunctionNode compileFunctionBody(List<Parameter> parameters,
      Iterable<LetBinding> letBindings, Expression returnValue) {
    var body = <k.Statement>[];
    var positional = <k.VariableDeclaration>[];
    var named = <k.VariableDeclaration>[];
    var requiredCount = 0;
    // TODO: Async
    // TODO: Return type

    // TODO: Compile let bindings

    // Compile the return value
    var retVal = expressionCompiler.compile(returnValue);
    body.add(new k.ReturnStatement(retVal));

    return new k.FunctionNode(new k.Block(body),
        positionalParameters: positional,
        namedParameters: named,
        requiredParameterCount: requiredCount);
  }
}
