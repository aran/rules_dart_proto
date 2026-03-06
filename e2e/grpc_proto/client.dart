import 'package:grpc/grpc.dart';
import 'package:greeter_dart_proto/greeter.pbgrpc.dart';

Future<void> main() async {
  final channel = ClientChannel(
    'localhost',
    port: 50051,
    options: const ChannelOptions(
      credentials: ChannelCredentials.insecure(),
    ),
  );

  final stub = GreeterClient(channel);

  try {
    final response = await stub.greet(GreetRequest()..name = 'World');
    print('Server responded: ${response.message}');
  } finally {
    await channel.shutdown();
  }
}
