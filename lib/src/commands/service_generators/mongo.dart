import 'generator.dart';
import 'package:code_builder/code_builder.dart';
import 'package:inflection3/inflection3.dart';
import '../make/maker.dart';

class MongoServiceGenerator extends ServiceGenerator {
  const MongoServiceGenerator() : super('MongoDB');

  @override
  List<MakerDependency> get dependencies =>
      const [MakerDependency('angel3_mongo', '^7.0.0')];

  @override
  void applyToConfigureServer(
      LibraryBuilder library,
      MethodBuilder configureServer,
      BlockBuilder block,
      String? name,
      String lower) {
    configureServer.requiredParameters.add(Parameter((b) => b
      ..name = 'db'
      ..type = refer('Db')));
  }

  @override
  void applyToLibrary(LibraryBuilder library, String name, String lower) {
    library.directives.addAll([
      Directive.import('package:angel3_mongo/angel3_mongo.dart'),
      Directive.import('package:mongo_dart/mongo_dart.dart'),
    ]);
  }

  @override
  Expression createInstance(LibraryBuilder library, MethodBuilder methodBuilder,
      String name, String lower) {
    return refer('MongoService').newInstance([
      refer('db').property('collection').call([literal(pluralize(lower))])
    ]);
  }
}
