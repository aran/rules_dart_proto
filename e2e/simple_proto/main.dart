import 'package:person_dart_proto/person.pb.dart';
import 'package:address_dart_proto/address.pb.dart';

void main() {
  final address = Address()
    ..street = '123 Main St'
    ..city = 'Springfield'
    ..state = 'IL'
    ..zip = '62701';

  final person = Person()
    ..name = 'Alice'
    ..age = 30
    ..email = 'alice@example.com'
    ..homeAddress = address;

  print('Person: ${person.name}, age ${person.age}, email ${person.email}');
  print('Address: ${person.homeAddress.street}, ${person.homeAddress.city}');
  print('Encoded bytes: ${person.writeToBuffer().length}');
}
