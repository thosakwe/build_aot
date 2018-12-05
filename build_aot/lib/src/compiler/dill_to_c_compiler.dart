import 'package:c_builder/c_builder.dart' as c;
import 'package:code_buffer/code_buffer.dart';
import 'package:kernel/class_hierarchy.dart';
import 'package:kernel/core_types.dart';
import 'package:kernel/kernel.dart';

class DillToCCompiler extends Visitor {
  final CoreTypes coreTypes;
  final ClassHierarchy classHierarchy;
  final c.CompilationUnit compilationUnit = c.CompilationUnit();
  final c.CompilationUnit headerFile = c.CompilationUnit();
  final Set _compiled = new Set();

  DillToCCompiler(this.coreTypes, this.classHierarchy) {
    headerFile.body.add(c.Code('// GENERATED CODE - DO NOT MODIFY BY HAND'));
  }

  static final RegExp _forbidden = RegExp(r'[:@]');

  String convertName(CanonicalName name) {
    var b = StringBuffer();
    if (name.parent != null) b.write('${convertName(name.parent)}_');
    b.write('${name.name}');
    return b.toString().replaceAll(_forbidden, '_');
  }

  void generate(CodeBuffer buffer) {
    headerFile.generate(buffer);
    compilationUnit.generate(buffer);
  }

  @override
  visitComponent(Component node) {
    // First, start by compiling the entry point.
    var mainSig = c.FunctionSignature(c.CType.int, 'main')
      ..parameters.addAll([
        c.Parameter(c.CType.int, 'argc'),
        c.Parameter(c.CType.char.const$().pointer().pointer(), 'argv')
      ]);
    var main = c.CFunction(mainSig);
    compileFunctionInto(node.mainMethod.function, main.body);
    compilationUnit.body.add(main);
  }

  void compileProcedure(Procedure ctx) {
    if (_compiled.add(ctx)) {
      var sig =
          c.FunctionSignature(c.CType.void$, convertName(ctx.canonicalName));
      var fn = c.CFunction(sig);

      // TODO: Opt args
      for (var p in ctx.function.positionalParameters) {
        var type = compileType(p.type);
        sig.parameters.add(c.Parameter(type, p.name));
      }

      compileFunctionInto(ctx.function, fn.body);
      headerFile.body.add(sig);
      compilationUnit.body.add(fn);
    }
  }

  void compileFunctionInto(FunctionNode ctx, List<c.Code> out) {
    compileStatement(ctx.body, out);
  }

  void compileStatement(Statement ctx, List<c.Code> out) {
    if (ctx is Block) {
      ctx.statements.forEach((s) => compileStatement(s, out));
      return;
    }

    if (ctx is ReturnStatement) {
      var retVal = compileExpression(ctx.expression, out);
      out.add(retVal.asReturn());
      return;
    }

    if (ctx is ExpressionStatement) {
      var retVal = compileExpression(ctx.expression, out);
      out.add(retVal);
      return;
    }

    var s = c.Expression.value(
        'Cannot compile statement (${ctx.runtimeType}) $ctx');
    out.add(s);
    //throw new UnsupportedError('Cannot compile $ctx');
  }

  c.CType compileType(DartType ctx) {
    if (ctx is InterfaceType) {
      if (classHierarchy.isSubclassOf(ctx.classNode, coreTypes.stringClass)) {
        return c.CType.char.pointer();
      } else {
        return c.CType('FAIL${convertName(ctx.className.canonicalName)}');
      }
    } else if (ctx is DynamicType) {
      return c.CType.void$.pointer();
    }

    throw new UnsupportedError('Cannot compile type $ctx');
  }

  c.Expression compileExpression(Expression ctx, List<c.Code> out) {
    if (ctx is StringLiteral) {
      return c.Expression.value(ctx.value);
    }

    if (ctx is StaticInvocation) {
      // TODO: Named args
      var target = c.Expression(convertName(ctx.target.canonicalName));
      var args = <c.Expression>[];

      for (var arg in ctx.arguments.positional) {
        args.add(compileExpression(arg, out));
      }

      compileProcedure(ctx.target);
      return target.invoke(args);
    }

    throw new UnsupportedError('Cannot compile expression $ctx');
  }
}
