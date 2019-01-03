import 'package:bullseye/bullseye.dart';
import 'package:source_span/source_span.dart';

class TypeParser extends PrattParser<TypeNode> {
  TypeParser(Parser parser) : super(parser) {
    init();
  }

  TypeDeclaration parseTypeDeclaration(List<Token> comments) {
    // TODO: annotations
    var annotations = <Annotation>[];

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

    addPrefix(TokenType.lCurly, (p, token) => parseRecordType(token));

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

    composite(TokenType.times, (c, s, i) => new TupleType(c, s, i),
        (t) => t is TupleType);
    // composite(TokenType.bitwiseOr, (c, s, i) => new UnionType(c, s, i),
    //     (t) => t is UnionType);
    // addInfix(TokenType.nullable,
    //     (p, prec, left, token) => new NullableType(left, token));
  }

  RecordType parseRecordType([Token lCurly]) {
    List<Token> comments;

    if (lCurly == null) {
      if (parser.peek()?.type == TokenType.lCurly && parser.moveNext()) {
        comments = parser.lastComments;
        lCurly = parser.current;
      } else {
        comments = parser.parseComments();
        return null;
      }
    }

    var span = lCurly.span, lastSpan = span;
    var fields = <RecordTypeField>[];
    var field = parseRecordTypeField();

    while (field != null) {
      fields.add(field);
      span = span.expand(lastSpan = field.span);

      if (parser.peek()?.type == TokenType.semi && parser.moveNext()) {
        field = parseRecordTypeField();
      } else {
        break;
      }
    }

    if (parser.peek()?.type == TokenType.rCurly && parser.moveNext()) {
      span = span.expand(parser.current.span);
    } else {
      parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
          lastSpan, "Missing '}' in record type literal."));
      return null;
    }

    if (fields.isEmpty) {
      parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
          span, 'Record fields cannot be empty.'));
    }

    return RecordType(comments, span, fields);
  }

  RecordTypeField parseRecordTypeField() {
    var comments = parser.parseComments();
    bool isMutable = false;
    FileSpan span, lastSpan;

    if (parser.peek()?.type == TokenType.mutable && parser.moveNext()) {
      isMutable = true;
      span = lastSpan = parser.current.span;
    }

    if (parser.peek()?.type != TokenType.id || !parser.moveNext()) {
      if (isMutable) {
        parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
            span, "Missing identifier after 'mutable' keyword."));
      }

      return null;
    }

    var id = Identifier([], parser.current);

    if (isMutable) {
      span = span.expand(lastSpan = id.span);
    } else {
      span = lastSpan = id.span;
    }

    if (parser.peek()?.type == TokenType.colon && parser.moveNext()) {
      span = span.expand(lastSpan = parser.current.span);
      var type = parser.typeParser.parse();

      if (type == null) {
        parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
            lastSpan, "Missing type after ':' in record field '${id.name}'."));
        return null;
      }

      return RecordTypeField(comments, span, id, type, isMutable);
    } else {
      parser.exceptions.add(BullseyeException(
          BullseyeExceptionSeverity.error,
          lastSpan,
          "Missing ':' after identifier '${id.name}' in record field."));
      return null;
    }
  }
}
