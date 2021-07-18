import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:inflection3/inflection3.dart';
import 'package:io/ansi.dart';
import 'package:prompts/prompts.dart' as prompts;
import 'package:recase/recase.dart';
import '../service_generators/service_generators.dart';
import '../../util.dart';
import 'maker.dart';

class ServiceCommand extends Command {
  @override
  String get name => 'service';

  @override
  String get description => 'Generates an Angel service.';

  ServiceCommand() {
    argParser
      ..addFlag('typed',
          abbr: 't',
          help: 'Wrap the generated service in a `TypedService` instance.',
          negatable: false)
      ..addOption('name',
          abbr: 'n', help: 'Specifies a name for the service file.')
      ..addOption('output-dir',
          help: 'Specifies a directory to create the service file.',
          defaultsTo: 'lib/src/services');
  }

  @override
  void run() async {
    await loadPubspec();
    String? name;
    if (argResults!.wasParsed('name')) name = argResults!['name'] as String?;

    if (name?.isNotEmpty != true) {
      name = prompts.get('Name of service');
    }

    var deps = <MakerDependency>[
      const MakerDependency('angel3_framework', '^4.1.0')
    ];

    // '${pubspec.name}.src.services.${rc.snakeCase}'
    var rc = ReCase(name!);
    var serviceLib = Library((serviceLib) {
      var generator = prompts.choose(
          'Choose which type of service to create', serviceGenerators)!;

//      if (generator == null) {
//        _pen.red();
//        _pen('${Icon.BALLOT_X} \'$type\' services are not yet implemented. :(');
//        _pen();
//        throw 'Unrecognized service type: "$type".';
//      }

      for (var dep in generator.dependencies) {
        if (!deps.any((d) => d.name == dep.name)) deps.add(dep);
      }

      if (generator.goesFirst) {
        generator.applyToLibrary(serviceLib, name, rc.snakeCase);
        serviceLib.directives.add(
            Directive.import('package:angel3_framework/angel3_framework.dart'));
      } else {
        serviceLib.directives.add(
            Directive.import('package:angel3_framework/angel3_framework.dart'));
        generator.applyToLibrary(serviceLib, name, rc.snakeCase);
      }

      if (argResults!['typed'] as bool) {
        serviceLib.directives
            .add(Directive.import('../models/${rc.snakeCase}.dart'));
      }

      // configureServer() {}
      serviceLib.body.add(Method((configureServer) {
        configureServer
          ..name = 'configureServer'
          ..returns = refer('AngelConfigurer');

        configureServer.body = Block((block) {
          generator.applyToConfigureServer(
              serviceLib, configureServer, block, name, rc.snakeCase);

          // return (Angel app) async {}
          var closure = Method((closure) {
            closure
              ..modifier = MethodModifier.async
              ..requiredParameters.add(Parameter((b) => b
                ..name = 'app'
                ..type = refer('Angel')));
            closure.body = Block((block) {
              generator.beforeService(serviceLib, block, name, rc.snakeCase);

              // app.use('/api/todos', new MapService());
              var service = generator.createInstance(
                  serviceLib, closure, name, rc.snakeCase);

              if (argResults!['typed'] as bool) {
                var tb = TypeReference((b) => b
                  ..symbol = 'TypedService'
                  ..types.add(refer(rc.pascalCase)));
                service = tb.newInstance([service]);
              }

              block.addExpression(refer('app').property('use').call([
                literal('/api/${pluralize(rc.snakeCase)}'),
                service,
              ]));
            });
          });

          block.addExpression(closure.closure.returned);
        });
      }));
    });

    final outputDir = Directory.fromUri(
        Directory.current.uri.resolve(argResults!['output-dir'] as String));
    final serviceFile =
        File.fromUri(outputDir.uri.resolve('${rc.snakeCase}.dart'));
    if (!await serviceFile.exists()) await serviceFile.create(recursive: true);
    await serviceFile.writeAsString(
        DartFormatter().format(serviceLib.accept(DartEmitter()).toString()));

    print(green.wrap(
        '$checkmark Successfully generated service file "${serviceFile.absolute.path}".'));

    if (deps.isNotEmpty) await depend(deps);
  }
}
