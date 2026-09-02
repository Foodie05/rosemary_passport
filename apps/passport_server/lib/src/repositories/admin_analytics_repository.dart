import '../db/database.dart';

class AdminAnalyticsRepository {
  AdminAnalyticsRepository(this._db);

  final Database _db;

  Future<Map<String, dynamic>> dashboard({int days = 30}) async {
    final boundedDays = days.clamp(7, 180);
    final summary = await _db.execute('''
      select
        (select count(*) from users),
        (select count(*) from users where account_status = 'banned'),
        (select count(*) from oidc_clients where is_active = true),
        (select count(*) from oidc_clients where is_active = true and client_id <> 'first_party_web')
      ''');
    final growth = await _db.execute(
      '''
      with dates as (
        select generate_series(
          current_date - (cast(@days as integer) - 1), current_date, interval '1 day'
        )::date as day
      )
      select d.day,
             (select count(*) from users u where u.created_at < d.day + interval '1 day') as total_users,
             (select count(*) from users u where u.created_at >= d.day and u.created_at < d.day + interval '1 day') as new_users
      from dates d order by d.day
      ''',
      params: {'days': boundedDays},
    );
    final auth = await _db.execute(
      '''
      with dates as (
        select generate_series(
          current_date - (cast(@days as integer) - 1), current_date, interval '1 day'
        )::date as day
      ), login_counts as (
        select created_at::date as day, count(*) as value
        from audit_logs
        where action like 'user.login%'
          and created_at >= current_date - (cast(@days as integer) - 1)
        group by created_at::date
      ), authorization_counts as (
        select created_at::date as day, count(*) as value
        from oidc_auth_codes
        where created_at >= current_date - (cast(@days as integer) - 1)
        group by created_at::date
      )
      select d.day, coalesce(l.value, 0), coalesce(a.value, 0)
      from dates d
      left join login_counts l on l.day = d.day
      left join authorization_counts a on a.day = d.day
      order by d.day
      ''',
      params: {'days': boundedDays},
    );
    final verification = await _db.execute(
      '''
      with dates as (
        select generate_series(
          current_date - (cast(@days as integer) - 1), current_date, interval '1 day'
        )::date as day
      ), email_counts as (
        select created_at::date as day, count(*) as value
        from email_verification_codes
        where created_at >= current_date - (cast(@days as integer) - 1)
        group by created_at::date
      ), sms_counts as (
        select created_at::date as day, count(*) as value
        from activity_logs
        where category = 'authentication'
          and outcome = 'success'
          and route_template in (
            '/api/v1/auth/send-phone-code',
            '/api/v1/auth/send-phone-login-code',
            '/api/v1/auth/send-phone-register-code'
          )
          and created_at >= current_date - (cast(@days as integer) - 1)
        group by created_at::date
      )
      select d.day, coalesce(e.value, 0), coalesce(s.value, 0)
      from dates d
      left join email_counts e on e.day = d.day
      left join sms_counts s on s.day = d.day
      order by d.day
      ''',
      params: {'days': boundedDays},
    );
    final row = summary.single;
    return {
      'period_days': boundedDays,
      'summary': {
        'total_users': row[0],
        'banned_users': row[1],
        'active_oidc_clients': row[2],
        'active_third_party_oidc_clients': row[3],
      },
      'user_growth': growth
          .map(
            (item) => {
              'date': item[0].toString(),
              'total_users': item[1],
              'new_users': item[2],
            },
          )
          .toList(),
      'authentication_activity': auth
          .map(
            (item) => {
              'date': item[0].toString(),
              'logins': item[1],
              'authorizations': item[2],
            },
          )
          .toList(),
      'verification_activity': verification
          .map(
            (item) => {
              'date': item[0].toString(),
              'email_codes': item[1],
              'sms_codes': item[2],
            },
          )
          .toList(),
      'definitions': {
        'total_users': 'users 表中的当前账户总数。',
        'user_growth': '截至每日结束时累计注册账户数；新用户为该日创建的账户数。',
        'logins': '审计链中 user.login* 成功事件数。',
        'authorizations': '该日创建的 OIDC 授权码数量。',
        'email_codes': '该日创建的邮箱验证码发放尝试记录数量，不等同于邮件服务商最终投递成功数。',
        'sms_codes': '行为日志中成功返回的手机号验证码发送端点数量；仅覆盖本功能上线后的记录。',
      },
    };
  }
}
