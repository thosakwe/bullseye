class todo {
  final String text;
  final bool completed;

  todo({this.text, this.completed = false});

  bool operator ==(other) =>
      other is todo && other.text == text && other.completed == completed;

  todo copyWith({String text, bool completed}) {
    return todo(
        text: text ?? this.text, completed: completed ?? this.completed);
  }

  String toString() {
    return 'todo { text = $text; completed = $completed }';
  }
}

bool main() {
  var cleanYourRoom = todo(text: 'Clean your room!', completed: false);
  var dupe = cleanYourRoom.copyWith(text: 'Do the dishes!');
  return dupe.completed;
}
