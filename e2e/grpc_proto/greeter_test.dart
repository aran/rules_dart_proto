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
  await server.serve(port: 0);
  final channel = ClientChannel(
    'localhost',
    port: server.port!,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );
  try {
    final response = await GreeterClient(
      channel,
    ).greet(GreetRequest()..name = 'World');
    if (response.message != 'Hello, World!') {
      throw StateError('unexpected reply: ${response.message}');
    }
  } finally {
    await channel.shutdown();
    await server.shutdown();
  }
  print('gRPC round trip passed!');
}
