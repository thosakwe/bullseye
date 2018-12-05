import 'dart:async';
import 'dart:convert';
import 'package:bullseye/bullseye.dart';
import 'package:front_end/src/compute_platform_binaries_location.dart';
import 'package:kernel/class_hierarchy.dart' as k;
import 'package:kernel/core_types.dart' as k;
import 'package:kernel/kernel.dart' as k;
import 'package:kernel/library_index.dart' as k;
import 'package:kernel/type_environment.dart' as k;
import 'package:source_span/source_span.dart';
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
  final Map<k.VariableGet, k.Reference> procedureReferences = {};
  final Map<Uri, k.Source> uriToSource = {};
  final CompilationUnit compilationUnit;
  final Parser parser;
  BullseyeKernelExpressionCompiler expressionCompiler;
  k.Library library;
  k.LibraryIndex libraryIndex;
  k.Procedure mainMethod;
  SymbolTable<k.Expression> scope = new SymbolTable();
  k.ClassHierarchy classHierarchy;
  k.CoreTypes coreTypes;
  k.Component vmPlatform;
  k.TypeEnvironment types;

  final Set<Uri> _imported = new Set();

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
    libraryIndex = new k.LibraryIndex.all(vmPlatform);
    types = new k.TypeEnvironment(coreTypes, classHierarchy, strongMode: true);
    await import(Uri.parse('dart:core'), compilationUnit.span);
  }

  Future import(Uri uri, FileSpan span, {String alias}) async {
    // TODO: Alias support, show, hide
    if (_imported.add(uri)) {
      var lib = libraryIndex.tryGetLibrary(uri.toString());

      if (lib != null) {
      } else {
        // TODO: How to import...? (probably use package_resolver)
        // (Which ostensibly will involve compiling said dep)
        throw new UnimplementedError(
            'Cannot yet import external libraries. You tried to import $uri.');
      }

      // Copy in all public symbols from the library...
      for (var member in lib.members) {
        var name = member.name.name;

        if (!name.startsWith('_')) {
          try {
            var ref = member.canonicalName.getReference();
            var vGet = new k.VariableGet(
                new k.VariableDeclaration(name, type: member.getterType));
            scope.create(name, value: vGet, constant: true);
            if (member is k.Procedure)
              procedureReferences[vGet] = ref..node = member;
          } on StateError {
            var existing = scope.resolve(name).value.location.file;
            exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                span,
                "The symbol '' is imported from libraries $uri and $existing, and therefore is ambiguous."));
          }
        }
      }
    }
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
      // TODO: Work out forward and cyclic references...!
      for (var decl in compilationUnit.topLevelDeclarations) {
        if (decl is FunctionDeclaration) {
          var fn = compileFunctionDeclaration(decl);
          if (fn == null) continue;
          library.addMember(fn);
          if (decl.name.name == 'main') mainMethod = fn;

          // Add it to the scope
          var v = new k.VariableDeclaration(decl.name.name,
              type: fn.function.functionType);
          var vGet = new k.VariableGet(v);
          procedureReferences[vGet] = fn.reference;

          try {
            scope.create(decl.name.name, value: vGet, constant: true);
          } on StateError catch (e) {
            exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error, decl.name.span, e.message));
          }
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
    var s = scope.createChild();
    var body = <k.Statement>[];
    var positional = <k.VariableDeclaration>[];
    var named = <k.VariableDeclaration>[];
    var pGets = <ParameterGet>[];
    var requiredCount = 0;

    // TODO: Async

    // Declare each parameter
    for (var parameter in parameters) {
      // TODO: Get their real types
      var v = new k.VariableDeclaration(parameter.name.name);
      var vGet = new k.VariableGet(v);
      var pGet = new ParameterGet(parameter, vGet);

      try {
        s.create(parameter.name.name, value: pGet, constant: true);
        pGets.add(pGet);
      } on StateError catch (e) {
        exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error, parameter.name.span, e.message));
        return null;
      }
    }

    for (var binding in letBindings) {
      try {
        // Register within the current scope.
        var value = expressionCompiler.compile(binding.value, s);
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
    var retVal = expressionCompiler.compile(returnValue, s);

    // Add parameters
    // TODO: Named parameters
    // TODO: Default values
    for (var pGet in pGets) {
      requiredCount++;
      positional.add(pGet.value.variable);
    }

    // If there's a failure, make it return null.
    // The compilation error will prevent this from running, but this
    // will make completion, errors, etc. smarter.
    if (retVal == null) {
      var returnNull = new k.ReturnStatement(new k.NullLiteral());
      return new k.FunctionNode(returnNull,
          positionalParameters: positional,
          namedParameters: named,
          requiredParameterCount: requiredCount,
          returnType: types.nullType);
    } else {
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
}

class ParameterGet extends k.Expression {
  final Parameter parameter;
  final k.VariableGet value;

  ParameterGet(this.parameter, this.value);

  bool get isDynamic => type is k.DynamicType;

  k.DartType get type => value.variable.type;

  set type(k.DartType type) {
    if (value.variable.type is k.DynamicType) {
      value.variable.type = type;
    }
  }

  @override
  accept(k.ExpressionVisitor v) => value.accept(v);

  @override
  accept1(k.ExpressionVisitor1 v, arg) => value.accept1(v, arg);

  @override
  k.DartType getStaticType(k.TypeEnvironment types) =>
      value.getStaticType(types);

  @override
  transformChildren(k.Transformer v) => value.transformChildren(v);

  @override
  visitChildren(k.Visitor v) => value.visitChildren(v);
}
