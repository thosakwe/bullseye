import 'package:analyzer/dart/ast/ast.dart' as dart;
import 'package:analyzer/dart/ast/ast_factory.dart' as dart;
import 'package:bullseye_lang/src/analysis/value.dart';
import 'package:bullseye_lang/src/analysis/value_visitor.dart';

class ValueCompiler extends ValueVisitor<dart.Expression> {
}
