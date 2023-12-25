# Change Log

## 8.2.0

* Updated to `analyzer` 6.3.x
* Updated repository link
* Updated `lints` to 3.0.0

## 8.1.1

* Updated README
* Updated to logo

## 8.1.0

* Updated README
* Updated to logo
* Updated to `analyzer` 6.2.x
* Updated to support Dart SDK 3.1.x

## 8.0.0

* Required Dart SDK > 3.0.x
* Updated to `analyzer` 5.0.x

## 7.0.0

* Skipped release

## 6.0.0

* Updated Dart SDK to 2.16.x

## 5.0.0

* Skipped release

## 4.0.0

* Changed `pub` to `dart pub`
* Changed `pub build` to `dart build`
* Updated Dart SDK to 2.14.0

## 3.2.0

* Upgraded from `pedantic` to `lints` linter

## 3.1.1

* Fixed NNBD issues

## 3.1.0

* Upgraded to support `analyzer` 2.0.0

## 3.0.1

* Updated help to use `angel3`
* Updated to use `angel3` packages
* Updated screenshot

## 3.0.0

* Fixed NNBD issues
* Updated to use `angel3` packages
* Fixed incorrect import for new project
* Updated screenshot

## 3.0.0-beta.2

* Updated README

## 3.0.0-beta.1

* Migrated to work with Dart SDK 2.12.x Non NNBD
* Replaced `mustache4dart2` with `mustache_template`
* Replaced `inflection2` with `inflection3`

## 2.1.7+1

* Fix a bug where new directories were not being created in
`init`.

## 2.1.7

* Fix a bug where `ArgResults.arguments` was used in `init` instead of the
intended `ArgResults.rest`.
* Stop including `package:angel_model` imports in `make model`.
* Update dependencies in `make` commands.
* Fix `make model` to generate ORM + migration by default.
* Fix `MakerDependency` logic to print missing dependencies.

## 2.1.6

* Fix a bug where models always defaulted to ORM.
* Add GraphQL boilerplate.
* Automatically restore terminal colors on shutdown.

## 2.1.5+1

* Update to `inflection2`.

## 2.1.5

* Add `shared` boilerplates.
* Remove uncecessary `angel_model` imports.

## 2.1.4+1

* Patch `part of 'path'` renames.

## 2.1.4

* The `migration` argument to `model` just emits an annotation now.
* Add the ORM boilerplate.

## 2.1.3

* Fix generation of ORM models.
* A `--project-name` to `init` command.

## 2.1.2

* No migrations-by-default.

## 2.1.1

* Edit the way `rename` runs, leaving no corner unturned.

## 2.1.0

* Deprecate `angel install`.
* Rename projects using `snake_case`.
* `init` now fetches from `master`.
* Remove the `1.x` option.
* Add `make migration` command.
* Replace `{{oldName}}` in the `rename` command.
* `pub get` now runs with `inheritStdio`.

## 2.0.1

* `deploy systemd` now has an `--install` option, where you can immediately
spawn the service.

## 2.0.0

* `init` can now produce either 1.x or 2.x projects.
* Fixed deps for compatibility with Dart2 stable.

## 1.3.4

* Fix another typo.

## 1.3.3

* Fix a small typo in the model generator.

## 1.3.2

* Restore `part` directives in generated models.

## 1.3.1

* Add `deploy nginx` and `deploy systemd`.

## 1.3.0

* Focus on Dart2 from here on out.
* Update `code_builder`.
* More changes...

## 1.1.5

Deprecated several commands, in favor of the `make`
command:

* `controller`
* `plugin`
* `service`
* `test`

The `rename` command will now replace *all* occurrences
of the old project names with the new one in `config/`
YAML files, and also operates on the glob `config/**/*.yaml`.

Changed the call to run `angel start` to run `dart bin/server.dart` instead, after an
`init` command.
