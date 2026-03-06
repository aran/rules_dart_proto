import 'package:all_protos/address.pb.dart';
import 'package:all_protos/person.pb.dart';

void main() {
  final address = Address()
    ..street = '456 Oak Ave'
    ..city = 'Portland';

  final person = Person()
    ..name = 'Bob'
    ..homeAddress = address;

  print('Multi-dep test: ${person.name} at ${person.homeAddress.street}');
}
