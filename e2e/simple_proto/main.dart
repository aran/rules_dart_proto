import 'package:person_dart_proto/person.pb.dart';

void main() {
  final person = Person()
    ..name = 'Alice'
    ..age = 30
    ..email = 'alice@example.com';

  print('Person: ${person.name}, age ${person.age}, email ${person.email}');
  print('Encoded bytes: ${person.writeToBuffer().length}');
}
