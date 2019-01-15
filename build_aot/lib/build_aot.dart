import 'dart:async';
import 'package:build/build.dart';
import 'package:build_modules/build_modules.dart';
import 'package:kernel/text/ast_to_text.dart';
import 'package:kernel/kernel.dart';
import 'package:path/path.dart' as p;

Builder aotBuilder(BuilderOptions options) => _AotBuilder(options);

Builder textBuilder(_) => const _TextBuilder();

PostProcessBuilder cleanupBuilder(_) {
  return FileDeletingBuilder(['.txt']);
}

class _TextBuilder implements Builder {
  const _TextBuilder();

  @override
  Map<String, List<String>> get buildExtensions {
    return {
      '.dill': ['.txt']
    };
  }

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    var bytes = await buildStep.readAsBytes(buildStep.inputId);
    var linkedComponent = await loadComponentFromBytes(bytes);
    var txtId = buildStep.inputId.changeExtension('.txt');
    var buf = StringBuffer();
    var printer = Printer(buf, showExternal: false);
    printer.writeComponentFile(linkedComponent);
    buildStep.writeAsString(txtId, buf.toString());
  }
}

class _AotBuilder implements Builder {
  final BuilderOptions options;

  _AotBuilder(this.options);

  @override
  Map<String, List<String>> get buildExtensions {
    return {
      // moduleExtension(DartPlatform.dart2jsServer): ['.asm']
      '.dill': ['.asm']
    };
  }

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    var bytes = await buildStep.readAsBytes(buildStep.inputId);
    var linkedComponent = await loadComponentFromBytes(bytes);
    var asmId = buildStep.inputId.changeExtension('.asm');
    var buf = StringBuffer();
    var printer = Printer(buf, showExternal: false);
    printer.writeComponentFile(linkedComponent);
    buildStep.writeAsString(asmId, buf.toString());
  }
}
