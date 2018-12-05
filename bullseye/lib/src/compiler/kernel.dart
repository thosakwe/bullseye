import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bullseye/bullseye.dart';
import 'package:front_end/src/api_prototype/front_end.dart' as fe;
import 'package:front_end/src/api_unstable/dart2js.dart';
import 'package:front_end/src/compute_platform_binaries_location.dart';
import 'package:front_end/src/testing/compiler_common.dart';
import 'package:kernel/class_hierarchy.dart' as k;
import 'package:kernel/core_types.dart' as k;
import 'package:kernel/kernel.dart' as k;
import 'package:kernel/library_index.dart' as k;
import 'package:kernel/target/targets.dart';
import 'package:kernel/type_environment.dart' as k;
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
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
  final Map<Uri, k.Library> loadedLibraries = {};
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
  Uri platformStrongUri;
  k.Component vmPlatform;
  k.TypeEnvironment types;

  final Set<Uri> _imported = new Set();

  bool _compiled = false;

  BullseyeKernelCompiler(this.compilationUnit, this.parser) {
    var ctx = compilationUnit;
    // var reference = k.CanonicalName.root()
    //     .getChildFromUri(ctx.span.sourceUrl)
    //     .getReference();
    expressionCompiler = new BullseyeKernelExpressionCompiler(this);

    // TODO: This used to have a reference arg
    library = new k.Library(compilationUnit.span.sourceUrl,
        fileUri: compilationUnit.span.sourceUrl);
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
    platformStrongUri = libsUri.resolve('vm_platform_strong.dill');
    vmPlatform =
        await k.loadComponentFromBinary(platformStrongUri.toFilePath());
    coreTypes = new k.CoreTypes(vmPlatform);
    classHierarchy = new k.ClassHierarchy(vmPlatform);
    libraryIndex = new k.LibraryIndex.all(vmPlatform);
    types = new k.TypeEnvironment(coreTypes, classHierarchy, strongMode: true);

    // Read all imports
    await importLibrary(Uri.parse('dart:core'), compilationUnit.span);
    for (var directive in compilationUnit.directives) {
      if (directive is ImportDirective) {
        await importLibrary(
          directive.toUri(),
          directive.url.span,
          alias: directive.alias?.name,
          show: directive.show.map((s) => s.name).toList(),
          hide: directive.hide.map((s) => s.name).toList(),
        );
      }
    }
  }

  Future<k.Library> loadLibrary(Uri uri) async {
    var lib = libraryIndex.tryGetLibrary(uri.toString());

    if (lib != null) {
      return lib;
    } else if (loadedLibraries.containsKey(uri)) {
      return loadedLibraries[lib];
    } else {
      var resolved = await PackageResolver.current.resolveUri(uri);
      k.Component component;

      if (p.extension(resolved.path) == '.dart') {
        // Compile it via FASTA!
        var libsUri = await computePlatformBinariesLocation();
        var specUri =
            libsUri.replace(path: p.join(libsUri.path, '..', 'libraries.json'));
        var flags = new TargetFlags(strongMode: true);
        var target = new NoneTarget(flags);

        CompilerOptions options = new CompilerOptions()
          ..target = target
          ..strongMode = target.strongMode
          ..sdkSummary = platformStrongUri
          //..linkedDependencies = [platformStrongUri]
          ..librariesSpecificationUri = specUri
          ..packagesFileUri = await PackageResolver.current.packageConfigUri;

        component = await fe.kernelForComponent([resolved], options);

        if (component != null) {
          for (var lib in component.libraries) {
            lib.fileUri = resolved;
          }
        } else {
          throw new StateError('Compilation of file $uri to IR failed.');
        }
      } else if (p.extension(resolved.path) != '.dill') {
        throw new UnsupportedError('Cannot import file $uri.');
      }

      if (component.libraries.isNotEmpty) {
        return loadedLibraries[uri] = component.libraries.first;
      } else {
        throw new StateError(
            'File $uri does not contain any Dart or Bullseye libraries.');
      }
    }
  }

  static final Uri dartCoreUri = Uri.parse('dart:core');

  Future importLibrary(Uri uri, FileSpan span,
      {String alias,
      List<String> show = const [],
      List<String> hide = const []}) async {
    // TODO: Alias support (use a LibraryWrapper expression)
    if (_imported.add(uri)) {
      var lib = await loadLibrary(uri);

      if (uri != dartCoreUri)
        library.addDependency(new k.LibraryDependency.import(lib));

      bool canImport(String name) {
        if (show.isNotEmpty && !show.contains(name)) return false;
        if (hide.isNotEmpty && hide.contains(name)) return false;
        return true;
      }

      // Copy in all public symbols from the library...
      for (var clazz in lib.classes) {
        try {
          if (!canImport(clazz.name)) continue;
          var w = new TypeWrapper(clazz.thisType, clazz: clazz);
          scope.create(clazz.name, value: w, constant: true);
        } on StateError catch (e) {
          exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error, span, e.message));
        }
      }

      for (var type in lib.typedefs) {
        try {
          if (!canImport(type.name)) continue;
          var w = new TypeWrapper(type.type, typedef$: type);
          scope.create(type.name, value: w, constant: true);
        } on StateError catch (e) {
          exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error, span, e.message));
        }
      }

      for (var member in lib.members) {
        var name = member.name.name;
        if (!canImport(name)) continue;

        if (!name.startsWith('_')) {
          try {
            var ref = member.canonicalName.getReference();
            var vGet = new k.VariableGet(
                new k.VariableDeclaration(name, type: member.getterType));
            scope.create(name, value: vGet, constant: true);
            if (member is k.Procedure)
              procedureReferences[vGet] = ref..node = member;
          } on StateError catch (e) {
            // TODO: Why are some symbols redefined...?
            var existing = scope.resolve(name)?.value?.location?.file;
            var message = existing != null
                ? "The symbol '$name' is imported from libraries $uri and $existing, and therefore is ambiguous."
                : 'Error when importing $uri: ${e.message}';
            exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.warning, span, message));
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
    if (library.reference.canonicalName != null) {
      return new k.Reference()
        ..canonicalName = library.reference.canonicalName.getChild(name);
    } else {
      return new k.Reference();
    }
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

class TypeWrapper extends k.Expression {
  final k.DartType type;
  final k.Class clazz;
  final k.Typedef typedef$;

  TypeWrapper(this.type, {this.clazz, this.typedef$});

  @override
  accept(k.ExpressionVisitor v) => new k.InvalidExpression(
      'Cannot treat $type as though it were a regular object.');

  @override
  accept1(k.ExpressionVisitor1 v, arg) => accept(null);

  @override
  k.DartType getStaticType(k.TypeEnvironment types) => types.typeType;

  @override
  transformChildren(k.Transformer v) => null;

  @override
  visitChildren(k.Visitor v) => null;
}
