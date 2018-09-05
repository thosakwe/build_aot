import 'package:c_builder/c_builder.dart' as c;
import 'package:kernel/kernel.dart';

class DillToCCompiler extends Visitor {
  final c.CompilationUnit compilationUnit = new c.CompilationUnit();

  DillToCCompiler() {
    compilationUnit.body
        .add(new c.Code('// GENERATED CODE - DO NOT MODIFY BY HAND'));
  }

  @override
  visitComponent(Component node) {
    print('Whoo! ${node.mainMethod.name.name}');
    return super.visitComponent(node);
  }
}
