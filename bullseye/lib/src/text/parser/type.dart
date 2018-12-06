import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

class TypeParser extends PrattParser<TypeNode> {
  TypeParser(Parser parser) : super(parser) {
    init();
  }

  TypeDeclaration parseTypeDeclaration() {
    // TODO: annotations + comments
    var annotations = <Annotation>[];
    var comments = <Token>[];

    if (parser.peek()?.type == TokenType.type && parser.moveNext()) {
      var kw = parser.current;
      var span = kw.span, lastSpan = span;

      if (parser.peek()?.type == TokenType.id && parser.moveNext()) {
        var name = new Identifier([], parser.current);
        span = span.expand(lastSpan = name.span);

        if (parser.peek()?.type == TokenType.equals && parser.moveNext()) {
          span = span.expand(lastSpan = parser.current.span);

          var type = parse();

          if (type != null) {
            span = span.expand(type.span);
            return new TypeDeclaration(annotations, comments, span, name, type);
          } else {
            parser.exceptions.add(new BullseyeException(
                BullseyeExceptionSeverity.error,
                lastSpan,
                "Missing type after '='."));
            return null;
          }
        } else {
          parser.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              lastSpan,
              "Missing '=' after identifier '${name.name}'."));
          return null;
        }
      } else {
        parser.exceptions.add(new BullseyeException(
            BullseyeExceptionSeverity.error,
            lastSpan,
            "Missing identifier after keyword 'type'."));
        return null;
      }
    } else {
      return null;
    }
  }

  void init() {
    addPrefix(TokenType.id, (p, token) {
      var libraryName = new Identifier([], token);

      if (p.peek()?.type == TokenType.dot && p.moveNext()) {
        var dot = p.current;

        if (p.peek()?.type == TokenType.id && p.moveNext()) {
          var name = new Identifier([], p.current);
          var span = libraryName.span.expand(dot.span).expand(name.span);
          return new NamedType([], span, libraryName, name);
        } else {
          p.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              token.span,
              "Missing identifier after '.'."));
          return null;
        }
      } else {
        return new NamedType([], libraryName.span, null, libraryName);
      }
    });

    addPrefix(TokenType.lParen, (p, token) {
      var innermost = p.typeParser.parse();

      if (innermost != null) {
        if (p.peek()?.type == TokenType.rParen && p.moveNext()) {
          return new ParenthesizedType([],
              token.span.expand(innermost.span).expand(p.current.span),
              innermost);
        } else {
          p.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error, innermost.span, "Missing ')'."));
          return null;
        }
      } else {
        p.exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            token.span, "Missing type after '('."));
        return null;
      }
    });

    void composite(
        TokenType delimiter,
        TypeNode Function(List<Token>, FileSpan, List<TypeNode>) f,
        bool Function(TypeNode) isType) {
      addInfix(delimiter, (p, prec, left, token) {
        var right = p.typeParser.parse();
        var span = right == null
            ? null
            : left.span.expand(token.span).expand(right.span);

        var items = <TypeNode>[];

        if (isType(left)) {
          items.addAll((left as CompositeType).items);
        } else {
          items.add(left);
        }

        if (isType(right)) {
          items.addAll((right as CompositeType).items);
          return f(left.comments, span, items);
        } else if (right != null) {
          items.add(right);
          return f(left.comments, span, items);
        } else {
          p.exceptions.add(new BullseyeException(
              BullseyeExceptionSeverity.error,
              token.span,
              "Missing type after '${token.span.text}'."));
          return null;
        }
      });
    }

    composite(TokenType.comma, (c, s, i) => new TupleType(c, s, i),
        (t) => t is TupleType);
    composite(TokenType.bitwiseOr, (c, s, i) => new UnionType(c, s, i),
        (t) => t is UnionType);
    addInfix(TokenType.nullable,
        (p, prec, left, token) => new NullableType(left, token));
  }
}
