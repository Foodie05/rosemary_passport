import 'package:postgres/postgres.dart';

import '../config/app_config.dart';

class Database {
  Database(this.config);

  final AppConfig config;
  Connection? _connection;

  Future<Connection> get connection async {
    if (_connection != null) {
      return _connection!;
    }

    _connection = await Connection.open(
      Endpoint(
        host: config.dbHost,
        port: config.dbPort,
        database: config.dbName,
        username: config.dbUser,
        password: config.dbPassword,
      ),
      settings: ConnectionSettings(sslMode: _parseSslMode(config.dbSslMode)),
    );

    return _connection!;
  }

  Future<Result> execute(String sql, {Map<String, dynamic>? params}) async {
    final conn = await connection;
    return conn.execute(Sql.named(sql), parameters: params ?? const {});
  }

  Future<T> runTx<T>(Future<T> Function(Session session) fn) async {
    final conn = await connection;
    return conn.runTx<T>(fn);
  }

  Future<void> close() async {
    final conn = _connection;
    if (conn != null) {
      await conn.close();
      _connection = null;
    }
  }

  SslMode _parseSslMode(String raw) {
    switch (raw) {
      case 'disable':
        return SslMode.disable;
      case 'verify-full':
        return SslMode.verifyFull;
      case 'require':
      default:
        return SslMode.require;
    }
  }
}
