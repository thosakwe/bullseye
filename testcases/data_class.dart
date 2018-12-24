class Todo {
  final String text;
  final bool completed;

  Todo({this.text, this.completed = false});
}

bool main() {
  var cleanYourRoom = Todo(text: 'Clean your room!');
  var dupe = Todo(completed: cleanYourRoom.completed, text: 'Do the dishes!');
  return dupe.completed;
}
