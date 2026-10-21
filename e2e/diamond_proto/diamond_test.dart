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
  assert(
    person.common.value == order.common.value,
    'Common values should match',
  );
  assert(
    person.common.runtimeType == order.common.runtimeType,
    'Common types should be identical (no diamond)',
  );

  // Roundtrip
  final personBytes = person.writeToBuffer();
  final person2 = Person.fromBuffer(personBytes);
  assert(person2.common.value == 'shared', 'roundtrip failed');

  // 64-bit field: set through proto3 JSON so this file needs no fixnum import.
  final big = Order()..mergeFromProto3Json({'quantity': '9007199254740993'});
  final big2 = Order.fromBuffer(big.writeToBuffer());
  assert(big2.quantity.toString() == '9007199254740993', 'int64 roundtrip');

  print('Diamond dependency test passed!');
}
