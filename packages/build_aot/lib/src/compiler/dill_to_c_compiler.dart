import 'package:kernel/kernel.dart';

class DillToCCompiler extends Visitor {
  @override
  visitComponent(Component node) {
    print('Whoo! ${node.mainMethod.name.name}');
    return super.visitComponent(node);
  }
}
