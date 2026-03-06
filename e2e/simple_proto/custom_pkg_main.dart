import 'package:address_dart_proto/address.pb.dart';

void main() {
  final addr = Address()
    ..street = '123 Main St'
    ..city = 'Springfield';
  print('Custom package name works: $addr');
}
