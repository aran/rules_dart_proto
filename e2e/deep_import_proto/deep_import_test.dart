import 'package:types_dart_proto/common.pb.dart';
import 'package:api_v2_dart_proto/request.pb.dart';
import 'package:frontend_dart_proto/event.pb.dart';

void main() {
  final ts = Timestamp()
    ..seconds = 1700000
    ..nanos = 123;
  final meta = Metadata()
    ..creator = 'test'
    ..createdAt = ts;

  // Types from lib/shared/types/ used directly
  assert(meta.creator == 'test', 'creator mismatch');
  assert(meta.createdAt.seconds == 1700000, 'timestamp mismatch');

  // Types from services/api/v2/ importing lib/shared/types/
  final req = Request()
    ..id = 'req-1'
    ..endpoint = '/api/v2/foo'
    ..metadata = meta;
  final reqBytes = req.writeToBuffer();
  final req2 = Request.fromBuffer(reqBytes);
  assert(req2.id == 'req-1', 'request id mismatch');
  assert(req2.metadata.creator == 'test', 'request metadata mismatch');

  // Types from app/frontend/ importing both lib/shared/types/ and services/api/v2/
  final event = Event()
    ..name = 'click'
    ..metadata = meta
    ..originatingRequest = req;
  final eventBytes = event.writeToBuffer();
  final event2 = Event.fromBuffer(eventBytes);
  assert(event2.name == 'click', 'event name mismatch');
  assert(event2.metadata.creator == 'test', 'event metadata mismatch');
  assert(event2.originatingRequest.endpoint == '/api/v2/foo', 'event request mismatch');

  // Verify type identity: Metadata from all three packages is the same type
  assert(event2.metadata.runtimeType == req2.metadata.runtimeType,
      'Metadata type mismatch across packages');

  print('Deep import test passed!');
}
