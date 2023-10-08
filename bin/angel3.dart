#!/usr/bin/env dart

library angel3_cli.tool;

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:angel3_cli/angel3_cli.dart';
import 'package:io/ansi.dart';

void main(List<String> args) async {
  var runner = CommandRunner('angel3',
      '$asciiArt\n\nCommand-line tools for the Angel3 framework.\n\nhttps://angel3-framework.web.app');

  runner.argParser
      .addFlag('verbose', help: 'Print verbose output.', negatable: false);

  runner
    ..addCommand(DeployCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(KeyCommand())
    ..addCommand(InitCommand())
//    ..addCommand(InstallCommand())
    ..addCommand(RenameCommand())
    ..addCommand(MakeCommand());

  await runner.run(args).catchError((exc, st) {
    if (exc is String) {
      stdout.writeln(exc);
    } else {
      stderr.writeln('Oops, something went wrong: $exc');
      if (args.contains('--verbose')) {
        stderr.writeln(st);
      }
    }

    exitCode = 1;
  }).whenComplete(() {
    stdout.write(resetAll.wrap(''));
  });
}

const String asciiArt2 = '''

    ___    _   ________________   _____
   /   |  / | / / ____/ ____/ /  |__  /
  / /| | /  |/ / / __/ __/ / /    /_ < 
 / ___ |/ /|  / /_/ / /___/ /______/ / 
/_/  |_/_/ |_/\\____/_____/_____/____/ 
                                                                                                                       
''';

const String asciiArt = '''

     _    _   _  ____ _____ _     _____ 
    / \\  | \\ | |/ ___| ____| |   |___ / 
   / _ \\ |  \\| | |  _|  _| | |     |_ \\ 
  / ___ \\| |\\  | |_| | |___| |___ ___) |
 /_/   \\_\\_| \\_|\\____|_____|_____|____/                                                                                 
''';

const String asciiArt3 = '''
                                             
     \\      \\  |   ___|  ____|  |     ___ /  
    _ \\      \\ |  |      __|    |       _ \\  
   ___ \\   |\\  |  |   |  |      |        ) | 
 _/    _\\ _| \\_| \\____| _____| _____| ____/  
                                             
''';
const String asciiArtOld = '''
____________   ________________________ 
___    |__  | / /_  ____/__  ____/__  / 
__  /| |_   |/ /_  / __ __  __/  __  /  
_  ___ |  /|  / / /_/ / _  /___  _  /___
/_/  |_/_/ |_/  \\____/  /_____/  /_____/
                                        
''';
