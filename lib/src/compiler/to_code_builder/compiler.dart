import 'package:bullseye_lang/src/analysis/function.dart';
import 'package:bullseye_lang/src/analysis/function_target.dart';
import 'package:bullseye_lang/src/analysis/function_target_visitor.dart';
import 'package:bullseye_lang/src/analysis/value.dart';
import 'package:bullseye_lang/src/analysis/value_visitor.dart';
import 'package:code_builder/code_builder.dart' as dart;

import 'context.dart';
import 'expr_compiler.dart';
import 'stmt_compiler.dart';

class Compiler {
  late ExprCompiler _exprCompiler;
  late StmtCompiler _stmtCompiler;

  dart.Method compileFunction(BullseyeFunction node) {
    return dart.Method((method) {
      /// TODO(thosakwe): Params, etc.
      method.body = dart.Block((block) {
        final ctx = BlockContext(block, method, true);
        final result = node.acceptArg1(ctx, _stmtCompiler);
        if (result != null) {
          block.addExpression(result.returned);
        }
      });
    });
  }
}
