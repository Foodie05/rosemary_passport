import 'dart:developer' as developer;

enum RosmLogLevel {
  debug(10, 'DEBUG'),
  info(20, 'INFO'),
  warning(30, 'WARN'),
  error(40, 'ERROR');

  const RosmLogLevel(this.priority, this.label);

  final int priority;
  final String label;
}

class RosmLogRecord {
  const RosmLogRecord({
    required this.level,
    required this.message,
    required this.timestamp,
    this.source = 'rosm_passport_flutter',
    this.event,
    this.context = const {},
    this.error,
    this.stackTrace,
  });

  final RosmLogLevel level;
  final String source;
  final String? event;
  final String message;
  final DateTime timestamp;
  final Map<String, Object?> context;
  final Object? error;
  final StackTrace? stackTrace;

  Map<String, Object?> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'source': source,
      if (event != null) 'event': event,
      'message': message,
      if (context.isNotEmpty) 'context': context,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack_trace': stackTrace.toString(),
    };
  }

  @override
  String toString() {
    final eventLabel = event == null ? '' : ' [$event]';
    final contextLabel = context.isEmpty ? '' : ' $context';
    return '${timestamp.toIso8601String()} ${level.label} '
        '$source$eventLabel $message$contextLabel';
  }
}

typedef RosmLogSink = void Function(RosmLogRecord record);

class RosmPassportLogger {
  RosmPassportLogger({
    this.minLevel = RosmLogLevel.info,
    Iterable<RosmLogSink> sinks = const [],
    this.outputToDeveloperLog = false,
  }) : _sinks = List.unmodifiable(sinks),
       _disabled = false;

  const RosmPassportLogger.disabled()
    : minLevel = RosmLogLevel.error,
      outputToDeveloperLog = false,
      _sinks = const [],
      _disabled = true;

  factory RosmPassportLogger.console({
    RosmLogLevel minLevel = RosmLogLevel.debug,
    Iterable<RosmLogSink> sinks = const [],
  }) {
    return RosmPassportLogger(
      minLevel: minLevel,
      sinks: sinks,
      outputToDeveloperLog: true,
    );
  }

  final RosmLogLevel minLevel;
  final bool outputToDeveloperLog;
  final List<RosmLogSink> _sinks;
  final bool _disabled;

  bool isEnabled(RosmLogLevel level) {
    return !_disabled && level.priority >= minLevel.priority;
  }

  void debug(
    String message, {
    String? source,
    String? event,
    Map<String, Object?> context = const {},
  }) {
    log(
      RosmLogLevel.debug,
      message,
      source: source,
      event: event,
      context: context,
    );
  }

  void info(
    String message, {
    String? source,
    String? event,
    Map<String, Object?> context = const {},
  }) {
    log(
      RosmLogLevel.info,
      message,
      source: source,
      event: event,
      context: context,
    );
  }

  void warning(
    String message, {
    String? source,
    String? event,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      RosmLogLevel.warning,
      message,
      source: source,
      event: event,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error(
    String message, {
    String? source,
    String? event,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      RosmLogLevel.error,
      message,
      source: source,
      event: event,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void log(
    RosmLogLevel level,
    String message, {
    String? source,
    String? event,
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isEnabled(level)) return;
    final record = RosmLogRecord(
      level: level,
      source: source ?? 'rosm_passport_flutter',
      event: event,
      message: message,
      timestamp: DateTime.now(),
      context: Map.unmodifiable(context),
      error: error,
      stackTrace: stackTrace,
    );

    if (outputToDeveloperLog) {
      developer.log(
        record.toString(),
        name: record.source,
        level: record.level.priority,
        error: error,
        stackTrace: stackTrace,
      );
    }

    for (final sink in _sinks) {
      try {
        sink(record);
      } on Object catch (sinkError, sinkStackTrace) {
        if (outputToDeveloperLog) {
          developer.log(
            'ROSM Passport log sink failed.',
            name: 'rosm_passport_flutter',
            level: RosmLogLevel.error.priority,
            error: sinkError,
            stackTrace: sinkStackTrace,
          );
        }
      }
    }
  }
}

class RosmPassportLogging {
  RosmPassportLogging._();

  static RosmPassportLogger logger = const RosmPassportLogger.disabled();

  static void configure(RosmPassportLogger nextLogger) {
    logger = nextLogger;
  }

  static void disable() {
    logger = const RosmPassportLogger.disabled();
  }
}
