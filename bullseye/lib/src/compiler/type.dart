import 'package:bullseye/bullseye.dart';
import 'package:kernel/ast.dart' as k;
import 'package:symbol_table/symbol_table.dart';

class BullseyeKernelTypeCompiler {
  final BullseyeKernelCompiler compiler;

  BullseyeKernelTypeCompiler(this.compiler);

  k.DartType compile(TypeNode ctx, SymbolTable<k.Expression> scope,
      [String name]) {
    if (ctx is NamedType)
      return compileNamed(ctx, scope);
    else if (ctx is RecordType) return compileRecord(ctx, scope, name);
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

  k.DartType compileRecord(RecordType ctx, SymbolTable<k.Expression> scope,
      [String name]) {
    // Return the type if it already exists.
    var existing = compiler.library.classes
        .firstWhere((c) => name != null && c.name == name, orElse: () => null);
    if (existing != null) return existing.thisType;

    name ??= scope.root.uniqueName('BullseyeRecord');

    var clazz = k.Class(
      name: name,
      reference: compiler.getReference(name),
      supertype: compiler.coreTypes.objectClass.asThisSupertype,
      fileUri: compiler.library.fileUri,
    );
    var fields = <String, k.DartType>{};
    var members = <String, k.Field>{};
    var isMutable = <String, bool>{};

    for (var field in ctx.fields) {
      var type = compile(field.type, scope);

      if (type == null) {
        compiler.exceptions.add(BullseyeException(
            BullseyeExceptionSeverity.error,
            field.span,
            "An error occurred while evaluating the type of the field '${field.name}'."));
      } else {
        fields[field.name] = type;
        isMutable[field.name] = field.isMutable;
      }
    }

    // TODO: Add fields
    fields.forEach((name, type) {
      var m = k.Field(
        k.Name(name),
        type: type,
        isFinal: !isMutable[name],
        hasImplicitGetter: true,
        hasImplicitSetter: isMutable[name],
        fileUri: compiler.library.fileUri,
      );
      clazz.addMember(members[name] = m);
    });

    var namedParams = fields.entries.map((entry) {
      return k.VariableDeclaration(
        entry.key,
        isFieldFormal: true,
        type: entry.value,
        initializer: k.NullLiteral(),
      );
      //return k.NamedExpression(name, value);
    }).toList();

    // TODO: Add constructor
    clazz.addMember(k.Constructor(
      k.FunctionNode(
        k.EmptyStatement(),
        namedParameters: namedParams,
        returnType: clazz.thisType,
      ),
      name: k.Name(''),
      // initializers: fields.keys.map<k.Initializer>((name) {
      //   return k.FieldInitializer(
      //     members[name],
      //     k.VariableGet(
      //       k.VariableDeclaration(name),
      //     ),
      //   );
      // }),
      initializers: namedParams.map<k.Initializer>((vDecl) {
        return k.FieldInitializer(
          members[vDecl.name],
          k.VariableGet(vDecl),
        );
      }).followedBy([
        k.SuperInitializer(
          compiler.coreTypes.objectClass.constructors[0],
          k.Arguments([]),
        ),
      ]).toList(),
    ));

    // TODO: Add hashCode

    // TODO: Add ==

    // TODO: Add copyWith
    clazz.addMember(
      k.Procedure(
        k.Name('copyWith'),
        k.ProcedureKind.Method,
        k.FunctionNode(
          k.Block([
            k.ReturnStatement(
              k.NullLiteral(),
            ),
          ]),
          namedParameters: namedParams,
          returnType: clazz.thisType,
        ),
        fileUri: compiler.library.fileUri,
      ),
    );

    // TODO: Add toString()
    // By this point, the class is already in the library - don't add it twice.
    compiler.library.addClass(clazz);
    compiler.classHierarchy.applyTreeChanges([], [compiler.library]);
    return clazz.thisType;
  }
}
