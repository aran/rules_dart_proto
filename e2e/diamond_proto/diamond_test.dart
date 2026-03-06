import 'package:common_dart_proto/common.pb.dart';
import 'package:person_dart_proto/person.pb.dart';
import 'package:order_dart_proto/order.pb.dart';

void main() {
  final c = Common()..value = 'shared';
  final person = Person()
    ..name = 'Alice'
    ..common = c;
  final order = Order()
    ..id = 'order-1'
    ..common = c;

  // Same Common type — no diamond problem
  assert(person.common.value == order.common.value,
      'Common values should match');
  assert(person.common.runtimeType == order.common.runtimeType,
      'Common types should be identical (no diamond)');

  // Roundtrip
  final personBytes = person.writeToBuffer();
  final person2 = Person.fromBuffer(personBytes);
  assert(person2.common.value == 'shared', 'roundtrip failed');

  print('Diamond dependency test passed!');
}
