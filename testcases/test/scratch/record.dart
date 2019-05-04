class todo {
  final String text;
  final bool completed;
  todo({this.text, this.completed});

  todo copyWith({String text, bool completed}) {
    return null;
  }
}

void main() {
  var cleanYourRoom = todo(text: "Clean your room!", completed: false);
  return print(cleanYourRoom.completed);
}
