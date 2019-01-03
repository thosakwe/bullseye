import 'package:bullseye/bullseye.dart';
import 'package:source_span/src/file.dart';

abstract class TypeNode extends Node {
  TypeNode(List<Token> comments, FileSpan span) : super(comments, span);

  TypeNode get innermost => this;
}

class ParenthesizedType extends TypeNode {
  final TypeNode innermost;

  ParenthesizedType(List<Token> comments, FileSpan span, this.innermost)
      : super(comments, span);
}

class NamedType extends TypeNode {
  final Identifier libraryName;
  final Identifier name;

  NamedType(List<Token> comments, FileSpan span, this.libraryName, this.name)
      : super(comments, span);
}

abstract class CompositeType extends TypeNode {
  final List<TypeNode> items;

  CompositeType(List<Token> comments, FileSpan span, this.items)
      : super(comments, span);
}

class TupleType extends CompositeType {
  TupleType(List<Token> comments, FileSpan span, List<TypeNode> items)
      : super(comments, span, items);
}

class UnionType extends CompositeType {
  UnionType(List<Token> comments, FileSpan span, List<TypeNode> items)
      : super(comments, span, items);
}

// class NonNullCoercedType extends TypeNode {
//   final TypeNode innermost;

//   NonNullCoercedType(this.innermost, Token punctuation)
//       : super(innermost.comments, innermost.span.expand(punctuation.span));
// }

// class NullableType extends TypeNode {
//   final TypeNode innermost;

//   NullableType(this.innermost, Token punctuation)
//       : super(innermost.comments, innermost.span.expand(punctuation.span));
// }

class RecordType extends TypeNode {
  final List<RecordTypeField> fields;

  RecordType(List<Token> comments, FileSpan span, this.fields)
      : super(comments, span);
}

class RecordTypeField extends Node {
  final Identifier identifier;
  final TypeNode type;
  final bool isMutable;

  RecordTypeField(List<Token> comments, FileSpan span, this.identifier,
      this.type, this.isMutable)
      : super(comments, span);

  String get name => identifier.name;
}
