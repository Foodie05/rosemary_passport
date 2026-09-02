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
      with bounds as (
        select (now() at time zone 'Asia/Shanghai')::date as today
      ), dates as (
        select generate_series(
          b.today - (cast(@days as integer) - 1), b.today, interval '1 day'
        )::date as day
        from bounds b
      )
      select to_char(d.day, 'YYYY-MM-DD'),
             (select count(*) from users u
              where u.created_at < ((d.day + 1)::timestamp at time zone 'Asia/Shanghai')) as total_users,
             (select count(*) from users u
              where u.created_at >= (d.day::timestamp at time zone 'Asia/Shanghai')
                and u.created_at < ((d.day + 1)::timestamp at time zone 'Asia/Shanghai')) as new_users
      from dates d order by d.day
      ''',
      params: {'days': boundedDays},
    );
    final auth = await _db.execute(
      '''
      with bounds as (
        select (now() at time zone 'Asia/Shanghai')::date as today
      ), dates as (
        select generate_series(
          b.today - (cast(@days as integer) - 1), b.today, interval '1 day'
        )::date as day
        from bounds b
      ), login_counts as (
        select (a.created_at at time zone 'Asia/Shanghai')::date as day,
               count(*) as value
        from audit_logs a cross join bounds b
        where action like 'user.login%'
          and a.created_at >= (
            (b.today - (cast(@days as integer) - 1))::timestamp
              at time zone 'Asia/Shanghai'
          )
        group by (a.created_at at time zone 'Asia/Shanghai')::date
      ), authorization_counts as (
        select (c.created_at at time zone 'Asia/Shanghai')::date as day,
               count(*) as value
        from oidc_auth_codes c cross join bounds b
        where c.created_at >= (
          (b.today - (cast(@days as integer) - 1))::timestamp
            at time zone 'Asia/Shanghai'
        )
        group by (c.created_at at time zone 'Asia/Shanghai')::date
      )
      select to_char(d.day, 'YYYY-MM-DD'), coalesce(l.value, 0), coalesce(a.value, 0)
      from dates d
      left join login_counts l on l.day = d.day
      left join authorization_counts a on a.day = d.day
      order by d.day
      ''',
      params: {'days': boundedDays},
    );
    final verification = await _db.execute(
      '''
      with bounds as (
        select (now() at time zone 'Asia/Shanghai')::date as today
      ), dates as (
        select generate_series(
          b.today - (cast(@days as integer) - 1), b.today, interval '1 day'
        )::date as day
        from bounds b
      ), email_counts as (
        select (e.created_at at time zone 'Asia/Shanghai')::date as day,
               count(*) as value
        from email_verification_codes e cross join bounds b
        where e.created_at >= (
          (b.today - (cast(@days as integer) - 1))::timestamp
            at time zone 'Asia/Shanghai'
        )
        group by (e.created_at at time zone 'Asia/Shanghai')::date
      ), sms_counts as (
        select (l.created_at at time zone 'Asia/Shanghai')::date as day,
               count(*) as value
        from activity_logs l cross join bounds b
        where l.category = 'authentication'
          and l.outcome = 'success'
          and l.route_template in (
            '/api/v1/auth/send-phone-code',
            '/api/v1/auth/send-phone-login-code',
            '/api/v1/auth/send-phone-register-code'
          )
          and l.created_at >= (
            (b.today - (cast(@days as integer) - 1))::timestamp
              at time zone 'Asia/Shanghai'
          )
        group by (l.created_at at time zone 'Asia/Shanghai')::date
      )
      select to_char(d.day, 'YYYY-MM-DD'), coalesce(e.value, 0), coalesce(s.value, 0)
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
        'user_growth': '北京时间每日结束时的累计注册账户数；新用户为该北京时间自然日创建的账户数。',
        'logins': '北京时间自然日内，审计链中 user.login* 成功事件数。',
        'authorizations': '北京时间自然日内创建的 OIDC 授权码数量。',
        'email_codes': '北京时间自然日内创建的邮箱验证码发放尝试记录数量，不等同于邮件服务商最终投递成功数。',
        'sms_codes': '北京时间自然日内，行为日志中成功返回的手机号验证码发送端点数量；仅覆盖本功能上线后的记录。',
      },
    };
  }
}
