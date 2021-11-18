// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:meta/meta.dart';

import 'runner.dart' as runner;
import 'src/artifacts.dart';
import 'src/base/context.dart';
import 'src/base/io.dart';
import 'src/base/logger.dart';
import 'src/base/platform.dart';
import 'src/base/template.dart';
import 'src/base/terminal.dart';
import 'src/base/user_messages.dart';
import 'src/cache.dart';
import 'src/commands/analyze.dart';
import 'src/commands/assemble.dart';
import 'src/commands/attach.dart';
import 'src/commands/build.dart';
import 'src/commands/channel.dart';
import 'src/commands/clean.dart';
import 'src/commands/config.dart';
import 'src/commands/create.dart';
import 'src/commands/custom_devices.dart';
import 'src/commands/daemon.dart';
import 'src/commands/debug_adapter.dart';
import 'src/commands/devices.dart';
import 'src/commands/doctor.dart';
import 'src/commands/downgrade.dart';
import 'src/commands/drive.dart';
import 'src/commands/emulators.dart';
import 'src/commands/format.dart';
import 'src/commands/generate.dart';
import 'src/commands/generate_localizations.dart';
import 'src/commands/ide_config.dart';
import 'src/commands/install.dart';
import 'src/commands/logs.dart';
import 'src/commands/make_host_app_editable.dart';
import 'src/commands/packages.dart';
import 'src/commands/precache.dart';
import 'src/commands/run.dart';
import 'src/commands/screenshot.dart';
import 'src/commands/shell_completion.dart';
import 'src/commands/symbolize.dart';
import 'src/commands/test.dart';
import 'src/commands/update_packages.dart';
import 'src/commands/upgrade.dart';
import 'src/devtools_launcher.dart';
import 'src/features.dart';
import 'src/globals_null_migrated.dart' as globals;
// Files in `isolated` are intentionally excluded from google3 tooling.
import 'src/isolated/mustache_template.dart';
import 'src/isolated/resident_web_runner.dart';
import 'src/pre_run_validator.dart';
import 'src/resident_runner.dart';
import 'src/runner/flutter_command.dart';
import 'src/web/web_runner.dart';

/// Main entry point for commands.
///
/// This function is intended to be used from the `flutter` command line tool.
Future<void> main(List<String> args) async {
  final bool veryVerbose = args.contains('-vv');
  final bool verbose = args.contains('-v') || args.contains('--verbose') || veryVerbose;
  final bool prefixedErrors = args.contains('--prefixed-errors');
  // Support the -? Powershell help idiom.
  final int powershellHelpIndex = args.indexOf('-?');
  if (powershellHelpIndex != -1) {
    args[powershellHelpIndex] = '-h';
  }

  final bool doctor = (args.isNotEmpty && args.first == 'doctor') ||
      (args.length == 2 && verbose && args.last == 'doctor');
  final bool help = args.contains('-h') || args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') || (args.length == 1 && verbose);
  final bool muteCommandLogging = (help || doctor) && !veryVerbose;
  final bool verboseHelp = help && verbose;
  final bool daemon = args.contains('daemon');
  final bool runMachine = (args.contains('--machine') && args.contains('run')) ||
                          (args.contains('--machine') && args.contains('attach'));

  // Cache.flutterRoot must be set early because other features use it (e.g.
  // enginePath's initializer uses it). This can only work with the real
  // instances of the platform or filesystem, so just use those.
  Cache.flutterRoot = Cache.defaultFlutterRoot(
    platform: const LocalPlatform(),
    fileSystem: globals.localFileSystem,
    userMessages: UserMessages(),
  );

  await runner.run(
    args,
    () => generateCommands(
      verboseHelp: verboseHelp,
      verbose: verbose,
    ),
    verbose: verbose,
    muteCommandLogging: muteCommandLogging,
    verboseHelp: verboseHelp,
    overrides: <Type, Generator>{
      // The web runner is not supported in google3 because it depends
      // on dwds.
      WebRunnerFactory: () => DwdsWebRunnerFactory(),
      // The mustache dependency is different in google3
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      // The devtools launcher is not supported in google3 because it depends on
      // devtools source code.
      DevtoolsLauncher: () => DevtoolsServerLauncher(
        processManager: globals.processManager,
        dartExecutable: globals.artifacts.getHostArtifact(HostArtifact.engineDartBinary).path,
        logger: globals.logger,
      ),
      Logger: () {
        final LoggerFactory loggerFactory = LoggerFactory(
          outputPreferences: globals.outputPreferences,
          terminal: globals.terminal,
          stdio: globals.stdio,
        );
        return loggerFactory.createLogger(
          daemon: daemon,
          machine: runMachine,
          verbose: verbose && !muteCommandLogging,
          prefixedErrors: prefixedErrors,
          windows: globals.platform.isWindows,
        );
      },
      PreRunValidator: () => PreRunValidator(fileSystem: globals.fs),
    },
  );
}

List<FlutterCommand> generateCommands({
  @required bool verboseHelp,
  @required bool verbose,
}) => <FlutterCommand>[
  AnalyzeCommand(
    verboseHelp: verboseHelp,
    fileSystem: globals.fs,
    platform: globals.platform,
    processManager: globals.processManager,
    logger: globals.logger,
    terminal: globals.terminal,
    artifacts: globals.artifacts,
  ),
  AssembleCommand(verboseHelp: verboseHelp, buildSystem: globals.buildSystem),
  AttachCommand(verboseHelp: verboseHelp),
  BuildCommand(verboseHelp: verboseHelp),
  ChannelCommand(verboseHelp: verboseHelp),
  CleanCommand(verbose: verbose),
  ConfigCommand(verboseHelp: verboseHelp),
  CustomDevicesCommand(
    customDevicesConfig: globals.customDevicesConfig,
    operatingSystemUtils: globals.os,
    terminal: globals.terminal,
    platform: globals.platform,
    featureFlags: featureFlags,
    processManager: globals.processManager,
    fileSystem: globals.fs,
    logger: globals.logger
  ),
  CreateCommand(verboseHelp: verboseHelp),
  DaemonCommand(hidden: !verboseHelp),
  DebugAdapterCommand(verboseHelp: verboseHelp),
  DevicesCommand(verboseHelp: verboseHelp),
  DoctorCommand(verbose: verbose),
  DowngradeCommand(verboseHelp: verboseHelp),
  DriveCommand(verboseHelp: verboseHelp,
    fileSystem: globals.fs,
    logger: globals.logger,
    platform: globals.platform,
  ),
  EmulatorsCommand(),
  FormatCommand(verboseHelp: verboseHelp),
  GenerateCommand(),
  GenerateLocalizationsCommand(
    fileSystem: globals.fs,
    logger: globals.logger,
  ),
  InstallCommand(),
  LogsCommand(),
  MakeHostAppEditableCommand(),
  PackagesCommand(),
  PrecacheCommand(
    verboseHelp: verboseHelp,
    cache: globals.cache,
    logger: globals.logger,
    platform: globals.platform,
    featureFlags: featureFlags,
  ),
  RunCommand(verboseHelp: verboseHelp),
  ScreenshotCommand(),
  ShellCompletionCommand(),
  TestCommand(verboseHelp: verboseHelp),
  UpgradeCommand(verboseHelp: verboseHelp),
  SymbolizeCommand(
    stdio: globals.stdio,
    fileSystem: globals.fs,
  ),
  // Development-only commands. These are always hidden,
  IdeConfigCommand(),
  UpdatePackagesCommand(),
];

/// An abstraction for instantiation of the correct logger type.
///
/// Our logger class hierarchy and runtime requirements are overly complicated.
class LoggerFactory {
  LoggerFactory({
    @required Terminal terminal,
    @required Stdio stdio,
    @required OutputPreferences outputPreferences,
    StopwatchFactory stopwatchFactory = const StopwatchFactory(),
  }) : _terminal = terminal,
       _stdio = stdio,
       _stopwatchFactory = stopwatchFactory,
       _outputPreferences = outputPreferences;

  final Terminal _terminal;
  final Stdio _stdio;
  final StopwatchFactory _stopwatchFactory;
  final OutputPreferences _outputPreferences;

  /// Create the appropriate logger for the current platform and configuration.
  Logger createLogger({
    @required bool verbose,
    @required bool prefixedErrors,
    @required bool machine,
    @required bool daemon,
    @required bool windows,
  }) {
    Logger logger;
    if (windows) {
      logger = WindowsStdoutLogger(
        terminal: _terminal,
        stdio: _stdio,
        outputPreferences: _outputPreferences,
        stopwatchFactory: _stopwatchFactory,
      );
    } else {
      logger = StdoutLogger(
        terminal: _terminal,
        stdio: _stdio,
        outputPreferences: _outputPreferences,
        stopwatchFactory: _stopwatchFactory
      );
    }
    if (verbose) {
      logger = VerboseLogger(logger, stopwatchFactory: _stopwatchFactory);
    }
    if (prefixedErrors) {
      logger = PrefixedErrorLogger(logger);
    }
    if (daemon) {
      return NotifyingLogger(verbose: verbose, parent: logger);
    }
    if (machine) {
      return AppRunLogger(parent: logger);
    }
    return logger;
  }
}
