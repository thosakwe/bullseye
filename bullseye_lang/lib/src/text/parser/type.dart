import 'package:bullseye_lang/bullseye_lang.dart';
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
            return new TypeDeclaration(annotations, comments, span, name,
                type..comments.insertAll(0, comments));
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

    addPrefix(TokenType.bitwiseOr, (p, token) => parseSumType(token: token));

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

    addInfix(TokenType.times, (p, prec, left, token) {
      var right = p.typeParser.parse();
      var span = right == null
          ? null
          : left.span.expand(token.span).expand(right.span);

      var items = <TypeNode>[];

      if (left is TupleType) {
        items.addAll(left.items);
      } else {
        items.add(left);
      }

      if (right is TupleType) {
        items.addAll(right.items);
        return TupleType(left.comments, span, items);
      } else if (right != null) {
        items.add(right);
        return TupleType(left.comments, span, items);
      } else {
        p.exceptions.add(new BullseyeException(BullseyeExceptionSeverity.error,
            token.span, "Missing type after '${token.span.text}'."));
        return null;
      }
    });

    // The leading "|" is not always there, so handle the case
    // where we get a named type that is actually a variant.
    addInfix(TokenType.bitwiseOr, (p, prec, left, token) {
      if (left is! NamedType) {
        parser.exceptions.add(BullseyeException(
            BullseyeExceptionSeverity.error,
            token.span,
            'The "|" operator may only be used to declare a sum type.'));
        return null;
      } else {
        return parseSumType(
          variant: SumTypeVariant(
            left.comments,
            left.span,
            (left as NamedType).name,
            null,
          ),
        );
      }
    });
    // composite(TokenType.bitwiseOr, (c, s, i) => new UnionType(c, s, i),
    //     (t) => t is UnionType);
    // addInfix(TokenType.nullable,
    //     (p, prec, left, token) => new NullableType(left, token));
  }

  SumType parseSumType({Token token, SumTypeVariant variant}) {
    var span = token?.span ?? variant.span, lastSpan = span;
    var variants = <SumTypeVariant>[];
    var comments = variant?.comments ?? parser.lastComments;
    variant ??= parseSumTypeVariant();
    while (variant != null) {
      span = span.expand(lastSpan = variant.span);
      variants.add(variant);
      if (parser.peek()?.type != TokenType.bitwiseOr || !parser.moveNext()) {
        break;
      } else {
        variant = parseSumTypeVariant();
      }
    }
    if (variants.isEmpty) {
      parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
          lastSpan, 'Sum types must have at least one variant.'));
      return null;
    } else {
      return SumType(comments, span, variants);
    }
  }

  SumTypeVariant parseSumTypeVariant() {
    if (parser.peek()?.type != TokenType.id || !parser.moveNext()) {
      return null;
    }

    var name = Identifier(parser.lastComments, parser.current);
    var span = name.span;
    TypeNode argument;
    if (parser.peek()?.type == TokenType.of && parser.moveNext()) {
      var of = parser.current.span;
      span = span.expand(of);
      if ((argument = parser.typeParser.parse()) == null) {
        parser.exceptions.add(BullseyeException(BullseyeExceptionSeverity.error,
            of, 'Missing type argument after "of".'));
      }
    }

    return SumTypeVariant(name.comments, span, name, argument);
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
