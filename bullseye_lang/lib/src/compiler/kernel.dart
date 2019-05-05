import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:front_end/src/api_prototype/front_end.dart' as fe;
import 'package:front_end/src/api_unstable/dart2js.dart';
import 'package:front_end/src/compute_platform_binaries_location.dart';
import 'package:front_end/src/testing/compiler_common.dart';
import 'package:kernel/class_hierarchy.dart' as k;
import 'package:kernel/core_types.dart' as k;
import 'package:kernel/kernel.dart' as k;
import 'package:kernel/library_index.dart' as k;
import 'package:kernel/target/targets.dart';
import 'package:kernel/text/ast_to_text.dart' as k;
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
  final Map<k.VariableGet, k.Reference> procedureReferences = {};

  /// Whether to include imported libraries in the generated component.
  final bool bundleExternal;
  final CompilationUnit compilationUnit;
  final Parser parser;
  BullseyeKernelExpressionCompiler expressionCompiler;
  BullseyeKernelTypeCompiler typeCompiler;
  k.Library library;
  k.LibraryIndex libraryIndex;
  SymbolTable<k.Expression> scope = new SymbolTable();
  k.ClassHierarchy classHierarchy;
  k.CoreTypes coreTypes;
  Uri platformStrongUri;
  k.Component vmPlatform;
  k.TypeEnvironment types;

  final k.Component _component = new k.Component();
  final Set<Uri> _imported = new Set();
  final _lazyTypes = <String, List<TypeWrapper>>{};

  bool _compiled = false;

  BullseyeKernelCompiler(this.compilationUnit, this.parser,
      {this.bundleExternal = false}) {
    var ctx = compilationUnit;
    // var reference = k.CanonicalName.root()
    //     .getChildFromUri(ctx.span.sourceUrl)
    //     .getReference();
    expressionCompiler = new BullseyeKernelExpressionCompiler(this);
    typeCompiler = new BullseyeKernelTypeCompiler(this);

    // TODO: This used to have a reference arg
    library = new k.Library(compilationUnit.span.sourceUrl,
        fileUri: compilationUnit.span.sourceUrl);
    _component.libraries.add(library);

    var ss = parser.scanner.scanner;
    var lineStarts = <int>[];

    while (!ss.isDone) {
      if (ss.scan('\n')) {
        lineStarts.add(ss.position);
      } else {
        ss.readChar();
      }
    }

    _component.uriToSource[ctx.span.sourceUrl] = new k.Source(
        lineStarts, utf8.encode(ss.string), library.importUri, library.fileUri);
  }

  Future initialize() async {
    var libsUri = await computePlatformBinariesLocation();
    platformStrongUri = libsUri.resolve('vm_platform_strong.dill');
    vmPlatform =
        await k.loadComponentFromBinary(platformStrongUri.toFilePath());
    coreTypes = new k.CoreTypes(vmPlatform);
    classHierarchy = new k.ClassHierarchy(vmPlatform);
    libraryIndex = new k.LibraryIndex.all(vmPlatform);
    types = new k.TypeEnvironment(coreTypes, classHierarchy);

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
    } else if (loadedLibraries[uri] != null) {
      return loadedLibraries[uri];
    } else {
      String packagesPath = p.join(p.current, '.packages');

      while (true) {
        var d = p.dirname(packagesPath);
        if (await File(packagesPath).exists()) {
          break;
        } else if (p.dirname(d) != d) {
          packagesPath = p.join(p.dirname(d), '.packages');
        } else {
          throw StateError(
              'No .packages file was found in ${p.current}, or any of its ancestors. Imports cannot be resolved.');
        }
      }

      // var packagesPath = p.join(p.current, '.packages');
      k.Component component;
      String packageName;

      var resolver = await PackageResolver.loadConfig(
          Uri(scheme: 'file', path: packagesPath));
      var resolved = await resolver.resolveUri(uri);

      if (resolved == null) {
        if (uri.scheme == 'package' && uri.pathSegments.isNotEmpty) {
          // TODO: Support local URI's
          packageName = uri.pathSegments[0];
          throw new StateError(
              'Cannot resolve URI $uri. `package:$packageName` seems to not be installed.');
        } else {
          throw new UnsupportedError('Cannot resolve URI $uri.');
        }
      } else {
        // Get the
      }

      // TODO: Auto-compile bullseye libraries?
      // TODO: Use .dill if available
      if (p.extension(resolved.path) == '.dart') {
        // See if we have already pre-compiled the file.
        // If .packages has been updated, then we need to recompile.
        var currentVersion = await File.fromUri(resolved).stat();
        var libraryPath = p.setExtension(
            p.join(
              p.current,
              '.dart_tool',
              'bullseye',
              'precompiled',
              Uri.encodeFull(resolved.toString()),
            ),
            '.dill');
        var versionPath = p.setExtension(libraryPath, '.version.txt');
        var libFile = File(libraryPath);
        var versionFile = File(versionPath);

        // If the library file exists, compare the version.
        if (await libFile.exists() && await versionFile.exists()) {
          var lastVersion = await versionFile.readAsString().then(int.parse);
          if (currentVersion != null &&
              lastVersion == currentVersion.modified.millisecondsSinceEpoch) {
            component = await k.loadComponentFromBinary(libraryPath);
          }
        }

        if (component == null) {
          // Compile it via FASTA!
          var libsUri = await computePlatformBinariesLocation();
          var specUri = libsUri.replace(
              path: p.join(libsUri.path, '..', 'libraries.json'));
          var flags = new TargetFlags();
          var target = new NoneTarget(flags);

          CompilerOptions options = new CompilerOptions()
            ..target = target
            ..sdkSummary = platformStrongUri
            ..linkedDependencies = [platformStrongUri]
            ..librariesSpecificationUri = specUri
            ..packagesFileUri = await resolver.packageConfigUri;

          resolved =
              resolved.replace(scheme: 'file', path: p.absolute(resolved.path));
          component = await fe.kernelForComponent([uri], options);

          if (component == null) {
            throw new StateError('Compilation of file $uri to IR failed.');
          } else {
            // Save the compiled library and version file.
            await Directory(p.dirname(libraryPath)).create(recursive: true);
            await versionFile.writeAsString(
                currentVersion.modified.millisecondsSinceEpoch.toString());
            await k.writeComponentToBinary(component, libraryPath);
          }
        }
      } else if (p.extension(resolved.path) != '.dill') {
        // TODO: Import dill
        throw new UnsupportedError('Cannot import file $uri.');
      }

      if (component.libraries.isNotEmpty) {
        // Load all libraries in.
        classHierarchy.applyTreeChanges([], component.libraries);
        // for (var lib in component.libraries) {
        //   loadedLibraries[lib.importUri] ??= lib;
        //   // TODO: This might break things
        //   //vmPlatform.libraries.add(lib);
        //   //classHierarchy = new k.ClassHierarchy(vmPlatform);
        // }

        var out = component.libraries.firstWhere((l) => l.importUri == resolved,
            orElse: () => component.libraries[0]);
        //out.importUri = uri;
        return out;
      } else {
        throw new StateError(
            'File $uri does not contain any Dart or Bullseye libraries.');
      }
    }
  }

  static final Uri dartCoreUri = Uri.parse('dart:core');

  Variable<k.Expression> resolveLazy(
      String name, FileSpan span, SymbolTable<k.Expression> scope) {
    var existing = scope.resolve(name);
    if (existing != null) return existing;
    if (!_lazyTypes.containsKey(name)) {
      exceptions.add(BullseyeException(BullseyeExceptionSeverity.error, span,
          'No symbol named "$name" exists in this context.'));
      return null;
    } else if (_lazyTypes[name].length > 1) {
      var libs = _lazyTypes[name].map((w) => w.libraryName).join(',');
      exceptions.add(BullseyeException(BullseyeExceptionSeverity.error, span,
          'The name "$name" is exported by multiple libraries ($libs).'));
      return null;
    } else {
      var type = _lazyTypes[name][0];
      return this.scope.create(name, value: type, constant: true);
    }
  }

  Future importLibrary(Uri uri, FileSpan span,
      {String alias,
      List<String> show = const [],
      List<String> hide = const []}) async {
    // TODO: Alias support (use a LibraryWrapper expression)
    void apply(k.Library lib) {
      if (lib == null) return;
      var uri = lib?.importUri;

      if (uri != dartCoreUri)
        library.addDependency(new k.LibraryDependency.import(lib));

      if (_imported.add(uri)) {
        bool canImport(String name) {
          // if (alias != null) {
          //   print('Skipping $name (no alias yet)');
          // }
          if (show.isNotEmpty && !show.contains(name)) return false;
          if (hide.isNotEmpty && hide.contains(name)) return false;
          return !name.startsWith('_');
        }

        // Copy in all public symbols from the library...
        void define(String name, TypeWrapper w) {
          // If this *exact* type has already been defined; just ignore it.
          if (_lazyTypes.containsKey(name)) {
            var existing = _lazyTypes[name];
            if (existing.any((ww) => w.isEquivalentTo(ww))) {
              // print('Skipped $name from $uri.');
              return;
            }
          }

          // TODO: Support library wrapper
          if (alias == null) {
            _lazyTypes.putIfAbsent(name, () => []).add(w);
            // print('Lazy-registed $name from $uri.');
            // scope.create(name, value: w, constant: true);
          }
        }

        for (var ref in lib.additionalExports) {
          try {
            if (ref.node is k.Typedef) {
              var type = ref.asTypedef;
              if (!canImport(type.name)) continue;
              var w = new TypeWrapper(type.type, typedef$: type);
              scope.create(type.name, value: w, constant: true);
            } else if (ref.node is k.Class) {
              var clazz = ref.asClass;
              if (!canImport(clazz.name)) continue;
              var w = new TypeWrapper(clazz.thisType, clazz: clazz);
              define(clazz.name, w);
            }
          } on StateError catch (e) {
            exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error, span, e.message));
          }
        }

        for (var clazz in lib.classes) {
          try {
            if (!canImport(clazz.name)) continue;
            var w = new TypeWrapper(clazz.thisType, clazz: clazz);
            define(clazz.name, w);
          } on StateError catch (e) {
            exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error, span, e.message));
          }
        }

        for (var type in lib.typedefs) {
          try {
            if (!canImport(type.name)) continue;
            var w = new TypeWrapper(type.type, typedef$: type);
            define(type.name, w);
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

    var lib = await loadLibrary(uri);
    apply(lib);
  }

  k.Component toComponent() {
    compile();

    // if (bundleExternal) {
    //   for (var dep in library.dependencies) {
    //     _component.libraries.add(dep.targetLibrary);
    //   }
    // }

    return _component;
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
      var types =
          compilationUnit.topLevelDeclarations.whereType<TypeDeclaration>();
      var functions =
          compilationUnit.topLevelDeclarations.whereType<FunctionDeclaration>();

      for (var decl in types) {
        var type = typeCompiler.compile(decl.type, scope, decl.name.name);

        if (type == null) {
          exceptions.add(BullseyeException(
              BullseyeExceptionSeverity.error,
              decl.span,
              "Evaluation of the typedef '${decl.name.name}' resulted in an error."));
        } else {
          TypeWrapper value;

          if (type is k.FunctionType) {
            var def = k.Typedef(decl.name.name, type);
            value = TypeWrapper(type, typedef$: def);
          } else if (type is k.InterfaceType) {
            value = TypeWrapper(type, clazz: type.classNode);
          } else {
            value = TypeWrapper(type);
          }

          try {
            scope.create(decl.name.name, value: value, constant: true);

            if (value.clazz != null) {
              if (!library.classes.contains(value.clazz))
                library.addClass(value.clazz);
            } else if (value.typedef$ != null) {
              library.addTypedef(value.typedef$);
            }
          } on StateError catch (e) {
            exceptions.add(BullseyeException(
                BullseyeExceptionSeverity.error, decl.span, e.message));
          } catch (e, st) {
            exceptions.add(BullseyeException(
                BullseyeExceptionSeverity.error,
                decl.span,
                'The Bullseye Compiler has encountered an uncaught error: $e\n$st\n\nPlease report it.'));
          }
        }
      }

      for (var decl in functions) {
        var fn = compileFunctionDeclaration(decl);
        if (fn == null) continue;
        library.addMember(fn);
        if (decl.name.name == 'main') _component.mainMethod = fn;

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

      _compiled = true;
    }
  }

  k.Procedure compileFunctionDeclaration(FunctionDeclaration ctx,
      [SymbolTable<k.Expression> scope, k.Reference ref]) {
    var name = new k.Name(ctx.name.name);
    var function = compileFunctionBody(
        ctx.parameterList.parameters,
        ctx.body.letBindings,
        [],
        ctx.body.returnValue,
        ctx.asyncMarker,
        scope ?? this.scope);
    if (function == null) return null;
    ref ??= getReference(ctx.name.name);
    var fn = new k.Procedure(name, k.ProcedureKind.Method, function,
        isStatic: true, reference: ref, fileUri: ctx.span.sourceUrl);
    ref.node = fn;
    return fn;
  }

  k.FunctionNode compileFunctionBody(
      List<Parameter> parameters,
      Iterable<LetBinding> letBindings,
      List<Expression> ignoredExpressions,
      Expression returnValue,
      k.AsyncMarker asyncMarker,
      SymbolTable<k.Expression> scope,
      // Use this if you need to fetch information (i.e. async marker)
      {BullseyeKernelExpressionCompiler localExprCompiler}) {
    var s = scope.createChild();
    var body = <k.Statement>[];
    var positional = <k.VariableDeclaration>[];
    var named = <k.VariableDeclaration>[];
    var pGets = <ParameterGet>[];
    var requiredCount = 0;
    localExprCompiler ??= this.expressionCompiler;

    // Declare each parameter
    for (var parameter in parameters) {
      // TODO: Get their real types
      var v = new k.VariableDeclaration(parameter.name.name);
      var vGet = new k.VariableGet(v);
      var pGet = new ParameterGet(parameter, vGet);

      if (parameter.type != null) {
        pGet.type = typeCompiler.compile(parameter.type, scope);
      }

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
        if (binding.functionDeclaration != null) {
          // Compile the function...
          var fn = compileFunctionDeclaration(
              binding.functionDeclaration, s, new k.Reference());
          var variable = new k.VariableDeclaration(
              binding.functionDeclaration.name.name,
              type: fn.function.functionType);
          var vGet = new k.VariableGet(variable);
          var decl = new k.FunctionDeclaration(variable, fn.function);
          body.add(decl);
          procedureReferences[vGet] = fn.reference..node = fn;
          s.create(binding.functionDeclaration.name.name,
              value: vGet, constant: true);
        } else {
          // Register within the current scope.
          var value = localExprCompiler.compile(binding.value, s);
          if (value == null) return null;
          var variable = new k.VariableDeclaration(binding.identifier.name,
              type: value.getStaticType(types));
          var vGet = new k.VariableGet(variable);
          s.create(binding.identifier.name, value: vGet, constant: true);

          // Then, just emit it within the body.
          //
          // There was big bug here before. Note that you must use the SAME VariableDeclaration instance.
          variable.initializer = value;
          body.add(variable);
        }
      } on StateError catch (e) {
        exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            binding.identifier.span, e.message));
        return null;
      }
    }

    // Compile all ignored expressions.
    for (var exp in ignoredExpressions) {
      var result = localExprCompiler.compile(exp, s);
      // print('${exp.span.text} => $result');
      if (result != null) {
        body.add(k.ExpressionStatement(result));
      }
    }

    // Compile the return value
    var retVal = localExprCompiler.compile(returnValue, s);

    if (retVal == null) {
      // An error has already been emitted, just return null in the meantime.
      retVal = new k.NullLiteral();
    }

    var returnType = retVal.getStaticType(types);

    // Get the discovered async marker.
    asyncMarker = localExprCompiler.asyncMarker;

    // Create a Future if necessary
    if (asyncMarker == k.AsyncMarker.Async) {
      // Import `dart:async`.
      var dartAsync = coreTypes.asyncLibrary;
      library.addDependency(new k.LibraryDependency.import(dartAsync));

      // Create a Future<X> type.
      var base = types.unfutureType(returnType);
      returnType = types.futureType(base);
    } else if (asyncMarker == k.AsyncMarker.AsyncStar) {
      // TODO: Do we need to unwrap this...?
    }

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
    // print('retVal = $retVal');
    if (retVal == null) {
      var returnNull = new k.ReturnStatement(new k.NullLiteral());
      return new k.FunctionNode(returnNull,
          positionalParameters: positional,
          namedParameters: named,
          requiredParameterCount: requiredCount,
          returnType: returnType,
          asyncMarker: asyncMarker);
    } else {
      body.add(new k.ReturnStatement(retVal));

      k.Statement out = new k.Block(body);

      if (letBindings.isEmpty && ignoredExpressions.isEmpty) {
        out = new k.ReturnStatement(retVal);
      }

      return new k.FunctionNode(out,
          positionalParameters: positional,
          namedParameters: named,
          requiredParameterCount: requiredCount,
          returnType: returnType,
          asyncMarker: asyncMarker);
    }
  }
}

class ParameterGet extends k.Expression {
  final Parameter parameter;
  final k.VariableGet value;

  ParameterGet(this.parameter, this.value);

  bool get isDynamic => type is k.DynamicType;

  k.DartType get type => value.variable.type;

  set type(k.DartType v) {
    if (value.variable.type is k.DynamicType && v != null) {
      value.variable.type = v;
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

  TypeWrapper(this.type, {this.clazz, this.typedef$}) {
    assert(clazz != null || typedef$ != null);
  }

  String get libraryName {
    if (clazz != null) {
      return clazz.enclosingLibrary.name;
    } else {
      return typedef$.enclosingLibrary.name;
    }
  }

  bool isEquivalentTo(TypeWrapper other) {
    if (clazz != null) {
      if (other.clazz == null) return false;
      return clazz.canonicalName.toString() ==
          other.clazz.canonicalName.toString();
    } else if (typedef$ != null) {
      if (other.typedef$ == null) return false;
      return typedef$.toString() == other.typedef$.canonicalName.toString();
    } else {
      return type == other.type;
    }
  }

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
