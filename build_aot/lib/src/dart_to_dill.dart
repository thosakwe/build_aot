import 'dart:async';
import 'dart:io' show BytesBuilder, Platform;
import 'package:build/build.dart';
import 'package:front_end/src/api_prototype/front_end.dart';
import 'package:front_end/src/api_prototype/standard_file_system.dart';
import 'package:front_end/src/compute_platform_binaries_location.dart';
import 'package:kernel/kernel.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/text/ast_to_text.dart';
import 'package:kernel/target/targets.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:scratch_space/scratch_space.dart';

class DartToDillBuilder implements Builder {
  const DartToDillBuilder();

  static final Resource<ScratchSpace> _space =
      new Resource(() => new ScratchSpace(), dispose: (old) => old.delete());

  @override
  Map<String, List<String>> get buildExtensions {
    return {
      '.dart': ['.dill', '.dill.txt']
    };
  }

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    var libsUri = await computePlatformBinariesLocation();
    var vmPlatform = libsUri.resolve('vm_platform_strong.dill');
    var libsJson = libsUri.resolve('../libraries.json');
    var options = CompilerOptions()
      ..declaredVariables = Platform.environment
      ..fileSystem = AssetFileSystem(buildStep)
      ..librariesSpecificationUri = libsJson
      ..sdkSummary = vmPlatform
      ..target = NoneTarget(TargetFlags())
      ..packagesFileUri = await PackageResolver.current.packageConfigUri;
    var space = await buildStep.fetchResource(_space);
    var dartFile = space.fileFor(buildStep.inputId);
    await space.ensureAssets([buildStep.inputId], buildStep);
    var component = await kernelForComponent([dartFile.uri], options);

    if (component != null) {
      var bin = buildStep.inputId.changeExtension('.dill');
      var txt = buildStep.inputId.changeExtension('.dill.txt');
      var bb = BytesSink(), bbb = StringBuffer();
      BinaryPrinter(bb)..writeComponentFile(component);
      Printer(bbb, showExternal: false)..writeComponentFile(component);
      buildStep.writeAsBytes(bin, bb.builder.takeBytes());
      buildStep.writeAsString(txt, bbb.toString());
    }
  }
}

class AssetFileSystem extends FileSystem {
  final BuildStep buildStep;

  AssetFileSystem(this.buildStep);

  @override
  FileSystemEntity entityForUri(Uri uri) {
    if (uri.scheme == 'package' || p.isAbsolute(uri.path)) {
      return StandardFileSystem.instance.entityForUri(uri);
    } else {
      var id = AssetId(
          buildStep.inputId.package, p.join(buildStep.inputId.path, uri.path));
      return _AssetFile(buildStep, id);
    }
  }
}

class _AssetFile extends FileSystemEntity {
  final AssetReader reader;
  final AssetId id;

  _AssetFile(this.reader, this.id);

  @override
  Future<bool> exists() {
    return reader.canRead(id);
  }

  @override
  Future<List<int>> readAsBytes() {
    return reader.readAsBytes(id);
  }

  @override
  Future<String> readAsString() {
    return reader.readAsString(id);
  }

  @override
  Uri get uri => id.uri;
}
