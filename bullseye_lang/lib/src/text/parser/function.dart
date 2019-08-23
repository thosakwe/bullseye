import 'package:bullseye_lang/bullseye_lang.dart';
import 'package:kernel/ast.dart' as k;
import 'package:source_span/source_span.dart';

class FunctionParser {
  final Parser parser;

  FunctionParser(this.parser);

  FunctionDeclaration parseFunctionDeclaration(
      List<Token> comments, bool maybeLetBinding) {
    if (parser.peek()?.type == TokenType.let && parser.moveNext()) {
      // TODO: Annotations
      var let = parser.current;
      var annotations = <Annotation>[];

      if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
        var id = new Identifier([], parser.current);
        var span = id.span;
        // TODO: Add an "unknown type" to signify errors
        var defaultBody = UnitLiteral(id.span);
        // var defaultBlock =
        //     new Block(comments, id.span, [], new NullLiteral([], id.span));
        var parameterList = parseParameterList(id.span, !maybeLetBinding);

        if (parameterList != null) {
          span = span.expand(parameterList.span);

          var asyncMarker = parser.parseAsyncMarker();

          if (parser.peek()?.type == TokenType.equals && parser.moveNext()) {
            var equals = parser.current;
            span = span.expand(equals.span);
            var body = parser.expressionParser.parse();
            // var body = parseBlock(equals.span);

            if (body != null) {
              span = span.expand(body.span);
              return new FunctionDeclaration(annotations, comments,
                  parameterList.span, id, parameterList, asyncMarker, body);
            } else {
              parser.exceptions.add(new BullseyeException(
                  BullseyeExceptionSeverity.error,
                  equals.span,
                  "Expected function body after '='."));
              return new FunctionDeclaration(annotations, comments, span, id,
                  parameterList, asyncMarker, defaultBody);
            }
          } else {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                id.span,
                "Expected '=' after parameter list."));
            return new FunctionDeclaration(
                annotations,
                comments,
                parameterList.span,
                id,
                parameterList,
                asyncMarker,
                defaultBody);
          }
        } else if (maybeLetBinding) {
          return null;
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              id.span,
              "Expected parameter list after identifier."));
          var defaultParameterList = new ParameterList([], id.span, []);
          return new FunctionDeclaration(annotations, comments, id.span, id,
              defaultParameterList, k.AsyncMarker.Sync, defaultBody);
        }
      } else {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            let.span,
            "Expected identifier after 'let' keyword."));
        return null;
      }
    } else {
      return null;
    }
  }

  Block parseBlock(FileSpan previousSpan) {
    assert(previousSpan != null);
    var bindings = <LetInExpression>[];
    var binding = parseLetBinding();
    var span = binding?.span ?? previousSpan, lastSpan = span;

    while (binding != null) {
      span = span.expand(lastSpan = binding.span);
      bindings.add(binding);
      binding = parseLetBinding();
    }

    var returnValue = parser.expressionParser.parse();

    if (returnValue != null) {
      span = span.expand(returnValue.span);
      return new Block([], span, bindings, returnValue);
    } else {
      parser.exceptions.add(new BullseyeException(
          BullseyeExceptionSeverity.error,
          lastSpan ?? previousSpan,
          "Missing expression at end of block."));
      return new Block(
          [], span ?? previousSpan, bindings, new NullLiteral([], span));
    }
  }

  LetInExpression parseLetBinding() {
    // Try to parse a function declaration.
    var decl = parser.runOrBacktrack(
        () => parseFunctionDeclaration(parser.parseComments(), true));

    if (decl != null) {
      // Read the `in` keyword, used to separate values.
      if (parser.peek()?.type != TokenType.in$ || !parser.moveNext()) {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            decl.span,
            "Expected 'in' after function declaration."));
      }

      return new LetInExpression.forFunction(decl);
    }

    if (parser.peek()?.type == TokenType.let && parser.moveNext()) {
      var let = parser.current;

      if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
        var id = new Identifier([], parser.current);
        var defaultValue = new NullLiteral([], id.span);

        if (parser.peek()?.type == TokenType.equals && parser.moveNext()) {
          var equals = parser.current;
          var value = parser.expressionParser.parse();

          if (value != null) {
            if (parser.peek()?.type != TokenType.in$ || !parser.moveNext()) {
              parser.exceptions.add(new BullseyeException(
                  BullseyeExceptionSeverity.error,
                  value.span,
                  "Expected 'in' after expression."));
            }

            return new LetInExpression(id.comments, id.span, id, value);
          } else {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                equals.span,
                "Expected expression after '='."));

            // Skip the `in` keyword, if there was an errant expression.
            if (parser.peek()?.type == TokenType.in$) parser.moveNext();

            return new LetInExpression(id.comments, id.span, id, defaultValue);
          }
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              id.span,
              "Expected '=' after identifier."));
          return new LetInExpression(id.comments, id.span, id, defaultValue);
        }
      } else {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            let.span,
            "Expected identifier after 'let' keyword."));
        return null;
      }
    } else {
      return null;
    }
  }

  ParameterList parseParameterList(FileSpan previousSpan, bool mustNotBeEmpty) {
    assert(previousSpan != null);
    var unit = parser.parseUnit();
    if (unit != null) {
      return new ParameterList(unit.comments, unit.span, []);
    } else {
      var parameters = <Parameter>[];
      var parameter = parseParameter();
      var span = previousSpan;

      while (parameter != null) {
        span = span.expand(parameter.span);
        parameters.add(parameter);
        parameter = parseParameter();
      }

      if (parameters.isEmpty) {
        if (!mustNotBeEmpty) {
          return null;
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              previousSpan,
              "Expected a list of parameters. If this function has no parameters, supply a '()' literal."));
          return new ParameterList([], span, []);
        }
      }

      return new ParameterList(parameters.first.comments, span, parameters);
    }
  }

  Parameter parseParameter() {
    return parser.expressionParser.parseFunctionExpressionParameter();
  }
}
