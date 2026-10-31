# AI Context: angel3-cli

Context for AI coding assistants working in this repository. Read this before making changes.

## What this is

`angel3_cli`, the command line tool for the [Angel3 framework](https://angel3-framework.web.app), installed with `dart pub global activate angel3_cli` and run as `angel3`. It scaffolds new projects from the [boilerplates](https://github.com/dart-backend/boilerplates) templates, generates code (models, controllers, services, plugins, tests, migrations), generates JWT secrets, and writes nginx/systemd deployment files.

- Repo: https://github.com/dart-backend/angel3-cli (contributors work from forks, e.g. `dukefirehawk/angel3-cli`)
- Package: `angel3_cli` 10.0.0, executable `angel3`
- Dart SDK: `>=3.13.0 <4.0.0`
- Single package: no workspace, no Melos

## Commands

Registered in `bin/angel3.dart`. Each is an `args` `Command` in `lib/src/commands/`, exported through `commands.dart`.

| Command | File | What it does |
|---|---|---|
| `init [dir]` | `init.dart` | Creates a project from a boilerplate template (see below) |
| `make <kind>` | `make.dart`, `make/*.dart` | Generates `controller`, `migration`, `model`, `plugin`, `service`, `test` with `code_builder` + `dart_style` |
| `key` | `key.dart` | Replaces `jwt_secret` in `config/default.yaml` and `config/production.yaml` |
| `rename` | `rename.dart` | Currently prints "not available"; its helpers `renamePubspec` and `renameDartFiles` are used by `init` |
| `deploy nginx` / `deploy systemd` | `deploy.dart`, `deploy/*.dart` | Writes deployment config files |
| `doctor` | `doctor.dart` | Only checks for `git` |
| `install` | `install.dart` | Deprecated and not registered in `bin/angel3.dart` |

`make service` uses the generators in `service_generators/` (map, file, mongo, rethink, custom).

## How `angel3 init` works

`lib/src/commands/init.dart`, with helpers in `lib/src/util.dart`:

1. If the target directory exists, the user is asked (`dcli.confirm`) before it's cleared.
2. The user picks a template from `dcli.menu`. Each template is a `BoilerplateInfo` constant: name, description, zipball URL (`repoLocation`, the GitHub API zipball of `dart-backend/boilerplates`), `subfolderPath` (e.g. `templates/basic_postgres_orm`), `ref` (`master`) and `needsPrebuild`.
3. A cached template under `~/.angel3/boilerplates/<subfolderPath>` that is newer than `templateCacheMaxAge` (one day) is reused, unless `--refresh` is given. With `--offline`, only the cache is used. Otherwise `downloadAndExtractSubfolder` streams the zipball into a hidden staging folder next to the cache (`.<name>_XXXX`), extracts only `subfolderPath` (rejecting paths that escape it), and swaps it into place. The old copy is moved aside first and restored if the swap fails. If the download fails, the cached copy is used. Staging folders over an hour old, left behind by an interrupted run, are deleted by the next download.
4. The template is copied into the project (`copyDirectory`, skipping `.git`).
5. New JWT secrets are written (`KeyCommand.changeSecret`).
6. The package is renamed from `templatePackageName` (`starter_app`) to `--project-name`, or to the snake_cased directory name (`renamePubspec`, `renameDartFiles`). If the template's `pubspec.yaml` is missing, unreadable or has a different name, the rename is skipped with a warning. The rename replaces substrings in config files, so it is only safe with a distinctive name like `starter_app`.
7. `dart pub get` runs, unless `--offline` or `--no-pub-get` is given.
8. For templates with `needsPrebuild: true` (GraphQL and both ORMs), `dart run build_runner build` runs if `pub get` succeeded. A failure is only a warning.

## Development Workflow

- **Master Branch**: Release branch; PRs target `master`. Work happens on `feature/<name>` branches (e.g. `feature/dart3.13`).
- **Setup**: `dart pub get`. To try the local build as the `angel3` command: `dart pub global activate --source path .`. Alternatively run `dart run bin/angel3.dart <command>`.
- **Checks**: Before finishing work, run:

  ```bash
  dart format --output=none --set-exit-if-changed .
  dart analyze
  ```

- **Tests**: There are none. `test/replace_name.dart` is a manual script, and `package:test` isn't a dependency. Verify changes by running the command, e.g. `dart run bin/angel3.dart init /tmp/demo` for each template. `init` is interactive (`dcli` prompts), so it needs a real terminal.
- **CI**: None. Run the checks locally.
- **Lints**: `package:lints/recommended.yaml`.
- **Releases**: Bump `version` in `pubspec.yaml` and add a `## <version>` entry to `CHANGELOG.md` as a short bullet list (e.g. "Required Dart SDK > 3.13.0", "Updated to `analyzer` 14.x.x"). SDK upgrades usually also bump `analyzer`, `lints` and the `MakerDependency` versions. Commit messages use [Conventional Commits](https://www.conventionalcommits.org/).
- **Changelog**: Every user-facing change gets an entry in the affected package's `CHANGELOG.md`, written as plain-English statements about the package (not commit messages). Group a release's entries under `### Breaking changes in X.Y.Z` (each entry prefixed `**Breaking:**`), `### New in X.Y.Z` and `### Fixes in X.Y.Z`, in that order, omitting empty sections. Prefix each fix with a bold area label, e.g. `* **Services:** An invalid id is a 400`. See `packages/framework/CHANGELOG.md` (10.0.0) for the reference style. Commit messages use [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): description`, `!` for breaking changes).

## Conventions

- Commands print user-facing progress with `package:io/ansi.dart` colours (`green`, `yellow`, `red`, `cyan`, `darkGray`) and `checkmark`/`ballot` from `util.dart`. Warnings are yellow and don't abort.
- Throwing a `String` from a command means a user-facing message with no "Oops" prefix (see the `catchError` in `bin/angel3.dart`). Throw an `Exception` for real errors.
- External processes run with `Process.start(..., mode: ProcessStartMode.inheritStdio)` so the user sees their output.
- Generated code is built with `code_builder` and formatted with `DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)`.
- `make` commands don't edit `pubspec.yaml`. `depend()` in `make/maker.dart` only prints the dependencies the user is missing.

## Gotchas

- **The CLI is coupled to the boilerplates repo.** It relies on the template folder names, the `starter_app` package name (`templatePackageName`; any other name skips the rename), the single-line `jwt_secret:` entries, and `master` as the download ref. Check the boilerplates repo before changing any of these, on either side.
- **`MakerDependency` versions are hardcoded** in `make/*.dart`. Keep them on the same Angel3 major as the boilerplates templates (currently `^10.0.0`, with `angel3_serialize_generator: ^10.0.1`), and bump them on every Angel3 major release.
- The template cache lives in `~/.angel3/boilerplates` (`angelDir` in `util.dart`; `HOME`, then `USERPROFILE`). Older releases used `~/.angel`.
- `install.dart`, `rename.dart` and `maker.dart` have large commented-out blocks waiting on [pubspec_parse#17](https://github.com/dart-lang/pubspec_parse/issues/17). Leave them unless you're asked to remove them.
- `archived/` holds old logo files and isn't part of the package. `.pubignore` excludes only `.vscode`.
- The GitHub zipball goes through the unauthenticated GitHub API, which is rate-limited (60 requests an hour per IP). That's why templates are cached for a day and the download falls back to the cache.
