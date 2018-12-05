import 'package:build/build.dart';
import 'src/dart_to_dill.dart';
import 'src/dill_to_c_builder.dart';

Builder dillBuilder(_) => const DartToDillBuilder();

Builder dillToCBuilder(_) => const DillToCBuilder();
