import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:io/ansi.dart';
import 'package:prompts/prompts.dart' as prompts;
import 'package:recase/recase.dart';
import '../../util.dart';
import 'maker.dart';

class ModelCommand extends Command {
  @override
  String get name => 'model';

  @override
  String get description => 'Generates a model class.';

  ModelCommand() {
    argParser
      ..addFlag('migration',
          abbr: 'm',
          help: 'Generate migrations when running `build_runner`.',
          defaultsTo: true)
      ..addFlag('orm', help: 'Generate angel_orm code.', negatable: false)
      ..addFlag('serializable',
          help: 'Generate angel_serialize annotations.', defaultsTo: true)
      ..addOption('name',
          abbr: 'n', help: 'Specifies a name for the model class.')
      ..addOption('output-dir',
          help: 'Specifies a directory to create the model class in.',
          defaultsTo: 'lib/src/models');
  }

  @override
  Future run() async {
    String? name;
    if (argResults?.wasParsed('name') == true) {
      name = argResults?['name'] as String?;
    }

    if (name?.isNotEmpty != true) {
      name = prompts.get('Name of model class');
    }

    var deps = <MakerDependency>[
      const MakerDependency('angel3_model', '^3.0.0'),
    ];

    var rc = ReCase(name!);

    var modelLib = Library((modelLib) {
      if (argResults?['orm'] as bool && argResults?['migration'] as bool) {
        modelLib.directives.addAll([
          Directive.import('package:angel3_migration/angel3_migration.dart'),
        ]);
      }

      var needsSerialize =
          argResults?['serializable'] as bool || argResults?['orm'] as bool;
      // argResults['migration'] as bool;

      if (needsSerialize) {
        modelLib.directives.add(
            Directive.import('package:angel3_serialize/angel3_serialize.dart'));
        deps.add(const MakerDependency('angel3_serialize', '^4.0.0'));
        deps.add(const MakerDependency('angel3_serialize_generator', '^4.0.0'));
        deps.add(const MakerDependency('build_runner', '^2.0.0'));
      }

      // else {
      //   modelLib.directives
      //       .add(new Directive.import('package:angel_model/angel_model.dart'));
      //   deps.add(const MakerDependency('angel_model', '^1.0.0'));
      // }

      if (argResults?['orm'] as bool) {
        modelLib.directives.addAll([
          Directive.import('package:angel3_orm/angel3_orm.dart'),
        ]);
        deps.add(const MakerDependency('angel3_orm', '^4.0.0'));
      }

      modelLib.body.addAll([
        Code("part '${rc.snakeCase}.g.dart';"),
      ]);

      modelLib.body.add(Class((modelClazz) {
        modelClazz
          ..abstract = true
          ..name = needsSerialize ? '_${rc.pascalCase}' : rc.pascalCase
          ..extend = refer('Model');

        if (needsSerialize) {
          // modelLib.addDirective(new PartBuilder('${rc.snakeCase}.g.dart'));
          modelClazz.annotations.add(refer('serializable'));
        }

        if (argResults?['orm'] as bool) {
          if (argResults?['migration'] as bool) {
            modelClazz.annotations.add(refer('orm'));
          } else {
            modelClazz.annotations.add(
                refer('Orm').call([], {'generateMigration': literalFalse}));
          }
        }
      }));
    });

    // Save model file
    var outputDir = Directory.fromUri(
        Directory.current.uri.resolve(argResults?['output-dir'] as String));
    var modelFile = File.fromUri(outputDir.uri.resolve('${rc.snakeCase}.dart'));
    if (!await modelFile.exists()) await modelFile.create(recursive: true);

    await modelFile.writeAsString(
        DartFormatter().format(modelLib.accept(DartEmitter()).toString()));

    print(green
        .wrap('$checkmark Created model file "${modelFile.absolute.path}".'));

    if (deps.isNotEmpty) await depend(deps);
  }
}
