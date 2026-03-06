import 'dart:io';

import 'package:protoc_plugin/bazel.dart';
import 'package:protoc_plugin/protoc.dart';

void main() {
  final packages = <String, BazelPackage>{};
  CodeGenerator(stdin, stdout).generate(
    optionParsers: {bazelOptionId: BazelOptionParser(packages)},
    config: BazelOutputConfiguration(packages),
  );
}
