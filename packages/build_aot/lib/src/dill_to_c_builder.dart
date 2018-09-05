import 'dart:async';

import 'package:build/build.dart';
import 'package:code_buffer/code_buffer.dart';
import 'package:kernel/binary/ast_from_binary.dart';
import 'package:kernel/kernel.dart';
import 'compiler/compiler.dart';

class DillToCBuilder implements Builder {
  const DillToCBuilder();

  @override
  Map<String, List<String>> get buildExtensions {
    return const {
      '.dill': const ['.c']
    };
  }

  @override
  Future build(BuildStep buildStep) async {
    try {
      var bytes = await buildStep.readAsBytes(buildStep.inputId);
      var component = await loadComponentFromBytes(bytes);
      var compiler = new DillToCCompiler();
      var buffer = new CodeBuffer();
      var outputId = buildStep.inputId.changeExtension('.c');
      component.accept(compiler);
      compiler.compilationUnit.generate(buffer);
      await buildStep.writeAsString(outputId, buffer.toString());
    } on InvalidKernelVersionError catch (e) {
      throw e.message;
    }
  }
}
