import 'package:grpc/grpc.dart';
import 'package:greeter_dart_proto/greeter.pbgrpc.dart';

class GreeterService extends GreeterServiceBase {
  @override
  Future<GreetResponse> greet(ServiceCall call, GreetRequest request) async {
    return GreetResponse()..message = 'Hello, ${request.name}!';
  }
}

Future<void> main() async {
  final server = Server.create(services: [GreeterService()]);
  await server.serve(port: 50051);
  print('gRPC server listening on port ${server.port}...');
}
