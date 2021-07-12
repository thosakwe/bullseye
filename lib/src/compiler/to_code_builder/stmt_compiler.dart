import 'package:bullseye_lang/src/analysis/function.dart';
import 'package:bullseye_lang/src/analysis/function_target.dart';
import 'package:bullseye_lang/src/analysis/function_target_visitor.dart';
import 'package:bullseye_lang/src/analysis/value.dart';
import 'package:bullseye_lang/src/analysis/value_visitor.dart';
import 'package:code_builder/code_builder.dart' as dart;

import 'compiler.dart';
import 'context.dart';

/// Compiles Bullseye values 1:1 to Dart statements.
/// If the given value cannot be converted to a statement, then it is compiled
/// to a Dart expression, and then returned.
abstract class StmtCompiler
    implements ValueVisitorArg1<BlockContext, dart.Expression?> {}

