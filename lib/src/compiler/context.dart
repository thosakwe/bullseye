class Context {
  final bool isReturn;

  Context({this.isReturn = false});

  Context? _parent;

  Context createChild({bool isReturn = false}) =>
      Context(isReturn: isReturn).._parent = this;
}
