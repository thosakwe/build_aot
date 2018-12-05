import 'dart:async';

import 'package:build/build.dart';
import 'package:code_buffer/code_buffer.dart';
import 'package:front_end/src/compute_platform_binaries_location.dart';
import 'package:kernel/class_hierarchy.dart';
import 'package:kernel/core_types.dart';
import 'package:kernel/kernel.dart';
import 'package:kernel/binary/ast_from_binary.dart';
import 'package:kernel/transformations/treeshaker.dart';
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
      if (component.mainMethod == null) return null;

      // Load the SDK.
      var libsUri = await computePlatformBinariesLocation();
      var vmPlatform = libsUri.resolve('vm_platform_strong.dill');
      var sdk = await loadComponentFromBinary(vmPlatform.toFilePath());
      var coreTypes = CoreTypes(sdk);

      var mainLib = component.libraries[0];
      component.libraries.addAll(sdk.libraries);

      // Resolve all dependencies, and link them in.
      for (var dep in mainLib.dependencies) {
        log.info('Linking in library ${dep.targetLibrary.fileUri}...');
        await loadComponentFromBinary(
            dep.targetLibrary.fileUri.toFilePath(), component);
      }

      // Update the class hierarchy.

      var hierarchy = ClassHierarchy(component);

      // Tree shake it!
      //component = await transformComponent(coreTypes, hierarchy, component);

      // Now, just compile.
      var compiler = new DillToCCompiler(coreTypes, hierarchy);
      var buffer = new CodeBuffer();
      var outputId = buildStep.inputId.changeExtension('.c');
      component.accept(compiler);
      compiler.generate(buffer);
      await buildStep.writeAsString(outputId, buffer.toString());
    } on InvalidKernelVersionError catch (e) {
      throw e.message;
    }
  }
}
