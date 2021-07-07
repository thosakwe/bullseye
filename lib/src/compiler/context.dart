class Context {
  Context? _parent;

  Context createChild() => Context().._parent = this;
}
