import 'package:postgres/postgres.dart';
import 'package:pool/pool.dart' as resource_pool;

import '../config/app_config.dart';

class Database {
  Database(this.config)
    : _acquireGate = resource_pool.Pool(
        config.dbPoolMaxConnections,
        timeout: Duration(seconds: config.dbAcquireTimeoutSeconds),
      ),
      _pool = Pool<void>.withEndpoints(
        [
          Endpoint(
            host: config.dbHost,
            port: config.dbPort,
            database: config.dbName,
            username: config.dbUser,
            password: config.dbPassword,
          ),
        ],
        settings: PoolSettings(
          applicationName: 'rosm-passport',
          maxConnectionCount: config.dbPoolMaxConnections,
          connectTimeout: Duration(seconds: config.dbConnectTimeoutSeconds),
          queryTimeout: Duration(seconds: config.dbQueryTimeoutSeconds),
          sslMode: _parseSslModeValue(config.dbSslMode),
          onOpen: (connection) async {
            await connection.execute(
              'set statement_timeout = ${config.dbQueryTimeoutSeconds * 1000}',
            );
            await connection.execute(
              'set lock_timeout = ${config.dbLockTimeoutMilliseconds}',
            );
            await connection.execute(
              "set idle_in_transaction_session_timeout = '10s'",
            );
          },
        ),
      );

  final AppConfig config;
  final resource_pool.Pool _acquireGate;
  final Pool<void> _pool;

  Future<Result> execute(String sql, {Map<String, dynamic>? params}) async {
    return _acquireGate.withResource(
      () => _pool.execute(Sql.named(sql), parameters: params ?? const {}),
    );
  }

  Future<T> runTx<T>(Future<T> Function(Session session) fn) async {
    return _acquireGate.withResource(() => _pool.runTx<T>(fn));
  }

  Future<T> withConnection<T>(Future<T> Function(Connection connection) fn) {
    return _acquireGate.withResource(() => _pool.withConnection(fn));
  }

  Future<void> warmUp() async {
    final count = config.dbPoolMinConnections.clamp(
      1,
      config.dbPoolMaxConnections,
    );
    await Future.wait(
      List.generate(
        count,
        (_) => _pool.withConnection((connection) async {
          await connection.execute('select 1');
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }),
      ),
    );
  }

  Future<void> close() async {
    await _acquireGate.close();
    await _pool.close();
  }

  static SslMode _parseSslModeValue(String raw) {
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
