enum TokenType {
  // Symbols
  arroba,
  arrow,
  colon,
  comma,
  comment,
  dot,
  equals,
  notEquals,
  lBracket,
  rBracket,
  lCurly,
  rCurly,
  lParen,
  rParen,
  semi,
  singleQuote,
  doubleQuote,

  // Operators
  pipeline,
  doubleDot,
  tripleDot,

  // Nullability
  nonNull,
  nonNullAs,
  nonNullDot,
  nullable,
  nullableAssign,
  nullableDot,
  nullCoalescing,

  // Arithmetic
  exponent,
  times,
  div,
  mod,
  plus,
  minus,
  shiftLeft,
  shiftRight,

  // Boolean
  booleanAnd,
  booleanOr,
  lessThan,
  lessThanOrEqual,
  greaterThan,
  greaterThanOrEqual,

  // Bitwise
  bitwiseNegate,
  bitwiseAnd,
  bitwiseOr,
  bitwiseXor,

  // Keywords
  abstract$,
  as$,
  await$,
  async$,
  begin,
  class$,
  const$,
  else$,
  end,
  export,
  extends$,
  fun,
  hide,
  if$,
  implements$,
  import,
  in$,
  is$,
  isNot,
  let,
  proto,
  rec,
  show,
  throw$,
  step,
  type,
  val,

  // Values
  false$,
  true$,
  null$,
  hex,
  octal,
  binary,
  int$,
  intScientific,
  double$,
  doubleScientific,

  // String parts
  textStringPart,
  escapeStringPart,
  hexStringPart,
  unicodeStringPart,
  stringInterpStart,
  stringSingleInterpPart,
  escapedQuotePart,

  // ID
  id
}
