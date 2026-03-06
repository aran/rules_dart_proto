import 'package:address_dart_proto/address.pb.dart';
import 'package:models_dart_proto/product.pb.dart';
import 'package:models_dart_proto/user.pb.dart';
import 'package:person_dart_proto/person.pb.dart';

void main() {
  // Address roundtrip
  final addr = Address()
    ..street = '123 Main St'
    ..city = 'Springfield'
    ..state = 'IL'
    ..zip = '62701';
  final addrBytes = addr.writeToBuffer();
  final addr2 = Address.fromBuffer(addrBytes);
  assert(addr2.street == '123 Main St', 'street mismatch');
  assert(addr2.city == 'Springfield', 'city mismatch');
  assert(addr2.state == 'IL', 'state mismatch');
  assert(addr2.zip == '62701', 'zip mismatch');

  // Person with nested Address roundtrip
  final person = Person()
    ..name = 'Alice'
    ..age = 30
    ..email = 'alice@example.com'
    ..homeAddress = addr;
  final personBytes = person.writeToBuffer();
  final person2 = Person.fromBuffer(personBytes);
  assert(person2.name == 'Alice', 'name mismatch');
  assert(person2.age == 30, 'age mismatch');
  assert(person2.email == 'alice@example.com', 'email mismatch');
  assert(person2.homeAddress.street == '123 Main St', 'nested address mismatch');

  // Default values
  final empty = Person();
  assert(empty.name == '', 'default name should be empty');
  assert(empty.age == 0, 'default age should be 0');
  assert(!empty.hasHomeAddress(), 'should not have address by default');

  // Multi-src proto_library: User and Product in the same proto_library
  final seller = User()
    ..username = 'bob'
    ..address = addr;
  final product = Product()
    ..name = 'Widget'
    ..price = 999
    ..seller = seller;
  final productBytes = product.writeToBuffer();
  final product2 = Product.fromBuffer(productBytes);
  assert(product2.name == 'Widget', 'product name mismatch');
  assert(product2.price == 999, 'product price mismatch');
  assert(product2.seller.username == 'bob', 'seller username mismatch');
  assert(product2.seller.address.city == 'Springfield', 'seller address mismatch');

  print('All proto tests passed!');
}
