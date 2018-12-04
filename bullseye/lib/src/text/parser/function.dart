import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

class FunctionParser {
  final Parser parser;

  FunctionParser(this.parser);

  FunctionDeclaration parseFunctionDeclaration() {
    if (parser.peek()?.type == TokenType.let && parser.moveNext()) {
      // TODO: Annotations  + comments
      var let = parser.current;
      var annotations = <Annotation>[];
      var comments = <Token>[];

      if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
        var id = new Identifier([], parser.current);
        var defaultBlock =
            new Block(comments, id.span, [], new NullLiteral([], id.span));
        var parameterList = parseParameterList(id.span);

        if (parameterList != null) {
          if (parser.peek()?.type == TokenType.equals && parser.moveNext()) {
            var equals = parser.current;
            var block = parseBlock(equals.span);

            if (block != null) {
              return new FunctionDeclaration(annotations, comments,
                  parameterList.span, id, parameterList, block);
            } else {
              parser.exceptions.add(new BullseyeException(
                  BullseyeExceptionSeverity.error,
                  equals.span,
                  "Expected function body after '='."));
              return new FunctionDeclaration(annotations, comments, id.span, id,
                  parameterList, defaultBlock);
            }
          } else {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                id.span,
                "Expected '=' after parameter list."));
            return new FunctionDeclaration(annotations, comments,
                parameterList.span, id, parameterList, defaultBlock);
          }
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              id.span,
              "Expected parameter list after identifier."));
          var defaultParameterList = new ParameterList([], id.span, []);
          return new FunctionDeclaration(annotations, comments, id.span, id,
              defaultParameterList, defaultBlock);
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
    var bindings = <LetBinding>[];
    var binding = parseLetBinding();
    var span = binding?.span, lastSpan = span;

    while (binding != null) {
      span = span.expand(lastSpan = binding.span);
      bindings.add(binding);
      binding = parseLetBinding();
    }

    var returnValue = parser.expressionParser.parse();

    if (returnValue != null) {
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

  LetBinding parseLetBinding() {
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

            return new LetBinding(id.comments, id.span, id, value);
          } else {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                equals.span,
                "Expected expression after '='."));
            return new LetBinding(id.comments, id.span, id, defaultValue);
          }
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              id.span,
              "Expected '=' after identifier."));
          return new LetBinding(id.comments, id.span, id, defaultValue);
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

  ParameterList parseParameterList(FileSpan previousSpan) {
    var unit = parser.parseUnit();
    if (unit != null) {
      return new ParameterList(unit.comments, unit.span, []);
    } else {
      var parameters = <Parameter>[];
      var parameter = parseParameter();
      var span = parameter?.span;

      while (parameter != null) {
        span = span.expand(parameter.span);
        parameters.add(parameter);
        parameter = parseParameter();
      }

      if (parameters.isEmpty) {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            previousSpan,
            "Expected a list of parameters. If this function has no parameters, supply a '()' literal."));
        return new ParameterList(unit.comments, unit.span, []);
      }

      return new ParameterList(parameters.first.comments, span, parameters);
    }
  }

  Parameter parseParameter() {
    // TODO: Parse annotations + comments
    if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
      var id = new Identifier([], parser.current);
      return new Parameter([], id.comments, parser.current.span, id);
    } else {
      return null;
    }
  }
}
