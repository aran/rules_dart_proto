import 'package:my_address_protos/address.pb.dart';

void main() {
  final addr = Address()
    ..street = '123 Main St'
    ..city = 'Springfield';
  print('Custom package name works: $addr');
}
