import 'package:greeting_dart_proto/greeting.pb.dart';
import 'package:note_dart_proto/note.pb.dart';
import 'package:stamp_dart_proto/stamp.pb.dart';

void main() {
  final note = Note()
    ..greeting = (Greeting()..text = 'hello')
    ..stamp = (Stamp()..seconds = 42);
  final copy = Note.fromBuffer(note.writeToBuffer());
  assert(copy.greeting.text == 'hello', 'greeting mismatch');
  assert(copy.stamp.seconds == 42, 'stamp mismatch');
  print('OK');
}
