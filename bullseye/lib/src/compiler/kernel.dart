import 'dart:async';
import 'dart:convert';
import 'package:bullseye/bullseye.dart';
import 'package:front_end/src/compute_platform_binaries_location.dart';
import 'package:kernel/class_hierarchy.dart' as k;
import 'package:kernel/core_types.dart' as k;
import 'package:kernel/kernel.dart' as k;
import 'package:kernel/type_environment.dart' as k;
import 'package:string_scanner/string_scanner.dart';
import 'package:symbol_table/symbol_table.dart';

Future<k.Component> compileBullseyeToKernel(String source, sourceUrl,
    void onException(BullseyeException exceptions)) async {
  var ss = new SpanScanner(source, sourceUrl: sourceUrl);
  var scanner = new Scanner(ss)..scan();
  var parser = new Parser(scanner);
  var unit = parser.parse();
  var hasFatal = parser.exceptions
      .any((e) => e.severity == BullseyeExceptionSeverity.error);
  parser.exceptions.forEach(onException);

  if (!hasFatal) {
    var compiler = new BullseyeKernelCompiler(unit, parser);
    await compiler.initialize();
    var component = compiler.toComponent();
    var hasFatal = compiler.exceptions
        .any((e) => e.severity == BullseyeExceptionSeverity.error);
    compiler.exceptions.forEach(onException);
    if (!hasFatal) {
      return component;
    } else {
      return null;
    }
  } else {
    return null;
  }
}

class BullseyeKernelCompiler {
  final List<BullseyeException> exceptions = [];
  final List<k.Library> libraries = [];
  final Map<Uri, k.Source> uriToSource = {};
  final CompilationUnit compilationUnit;
  final Parser parser;
  BullseyeKernelExpressionCompiler expressionCompiler;
  k.Library library;
  k.Procedure mainMethod;
  SymbolTable<k.Expression> scope = new SymbolTable();
  k.ClassHierarchy classHierarchy;
  k.CoreTypes coreTypes;
  k.Component vmPlatform;
  k.TypeEnvironment types;

  bool _compiled = false;

  BullseyeKernelCompiler(this.compilationUnit, this.parser) {
    var ctx = compilationUnit;
    var reference = new k.Reference()
      ..canonicalName =
          k.CanonicalName.root().getChildFromUri(ctx.span.sourceUrl);
    expressionCompiler = new BullseyeKernelExpressionCompiler(this);

    library = new k.Library(compilationUnit.span.sourceUrl,
        reference: reference, fileUri: compilationUnit.span.sourceUrl);
    libraries.add(library);

    var ss = parser.scanner.scanner;
    var lineStarts = <int>[];

    while (!ss.isDone) {
      if (ss.scan('\n')) {
        lineStarts.add(ss.position);
      } else {
        ss.readChar();
      }
    }

    uriToSource[ctx.span.sourceUrl] =
        new k.Source(lineStarts, utf8.encode(ss.string));
  }

  Future initialize() async {
    var libsUri = await computePlatformBinariesLocation();
    var platformStringUri = libsUri.resolve('vm_platform_strong.dill');
    vmPlatform =
        await k.loadComponentFromBinary(platformStringUri.toFilePath());
    coreTypes = new k.CoreTypes(vmPlatform);
    classHierarchy = new k.ClassHierarchy(vmPlatform);
    types = new k.TypeEnvironment(coreTypes, classHierarchy, strongMode: true);
  }

  k.Component toComponent() {
    compile();

    return new k.Component(libraries: libraries, uriToSource: uriToSource)
      ..mainMethod = mainMethod;
  }

  k.Reference getReference(String name) {
    return new k.Reference()
      ..canonicalName = library.reference.canonicalName.getChild(name);
  }

  void compile() {
    if (!_compiled) {
      for (var decl in compilationUnit.topLevelDeclarations) {
        if (decl is FunctionDeclaration) {
          var fn = compileFunctionDeclaration(decl);
          if (fn == null) continue;
          library.addMember(fn);
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
    if (function == null) return null;
    var ref = getReference(ctx.name.name);
    var fn = new k.Procedure(name, k.ProcedureKind.Method, function,
        isStatic: true, reference: ref, fileUri: ctx.span.sourceUrl);
    ref.node = fn;
    return fn;
  }

  k.FunctionNode compileFunctionBody(List<Parameter> parameters,
      Iterable<LetBinding> letBindings, Expression returnValue) {
    var body = <k.Statement>[];
    var positional = <k.VariableDeclaration>[];
    var named = <k.VariableDeclaration>[];
    var requiredCount = 0;

    // TODO: Async

    for (var binding in letBindings) {
      try {
        // Register within the current scope.
        var value = expressionCompiler.compile(binding.value, scope);
        if (value == null) return null;
        var variable = new k.VariableDeclaration(binding.identifier.name,
            type: value.getStaticType(types));
        var vGet = new k.VariableGet(variable);
        scope.create(binding.identifier.name, value: vGet, constant: true);

        // Then, just emit it within the body.
        body.add(new k.VariableDeclaration(binding.identifier.name,
            initializer: value, type: variable.type));
      } on StateError catch (e) {
        exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            binding.identifier.span, e.message));
        return null;
      }
    }

    // Compile the return value
    var retVal = expressionCompiler.compile(returnValue, scope);
    body.add(new k.ReturnStatement(retVal));

    k.Statement out = new k.Block(body);

    if (letBindings.isEmpty) {
      out = new k.ReturnStatement(retVal);
    }

    return new k.FunctionNode(out,
        positionalParameters: positional,
        namedParameters: named,
        requiredParameterCount: requiredCount,
        returnType: retVal.getStaticType(types));
  }
}
