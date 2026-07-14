create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key,
  email text not null unique,
  phone_number text unique,
  nickname text not null,
  password_hash text not null,
  passkey_hash text,
  security_code_hash text,
  authenticator_secret text,
  authenticator_verified_at timestamptz,
  is_email_verified boolean not null default false,
  is_phone_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table users add column if not exists phone_number text;
alter table users add column if not exists is_phone_verified boolean not null default false;
create unique index if not exists idx_users_phone_number_unique on users(phone_number) where phone_number is not null;
alter table users add column if not exists passkey_hash text;
alter table users add column if not exists security_code_hash text;
alter table users add column if not exists authenticator_secret text;
alter table users add column if not exists authenticator_verified_at timestamptz;

create table if not exists user_roles (
  user_id uuid not null references users(id) on delete cascade,
  role text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'user_roles_role_check'
  ) then
    alter table user_roles drop constraint user_roles_role_check;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_roles_role_check'
  ) then
    alter table user_roles
      add constraint user_roles_role_check
      check (role in ('user', 'admin'));
  end if;
end $$;

create table if not exists email_verification_codes (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  code_hash text not null,
  purpose text not null,
  failed_attempts integer not null default 0,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
alter table email_verification_codes
  add column if not exists failed_attempts integer not null default 0;
create index if not exists idx_email_code_lookup on email_verification_codes(email, purpose, created_at desc);

create table if not exists oidc_clients (
  client_id text primary key,
  client_secret_hash text,
  redirect_uris text[] not null,
  scopes text[] not null default array['openid', 'profile', 'email', 'phone']::text[],
  grant_types text[] not null default array['authorization_code', 'refresh_token']::text[],
  is_confidential boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists oidc_auth_codes (
  code text primary key,
  client_id text not null references oidc_clients(client_id),
  user_id uuid not null references users(id) on delete cascade,
  redirect_uri text not null,
  scopes text[] not null,
  nonce text,
  code_challenge text,
  code_challenge_method text,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
alter table oidc_auth_codes add column if not exists nonce text;
create index if not exists idx_oidc_auth_codes_user on oidc_auth_codes(user_id);

create table if not exists oidc_access_tokens (
  token_id text primary key,
  user_id uuid not null references users(id) on delete cascade,
  client_id text not null references oidc_clients(client_id),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists oidc_refresh_tokens (
  token_id text primary key,
  user_id uuid not null references users(id) on delete cascade,
  client_id text not null references oidc_clients(client_id),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists app_authorizations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  client_id text not null references oidc_clients(client_id),
  scopes text[] not null,
  granted_at timestamptz not null default now(),
  unique(user_id, client_id)
);

create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  actor_id text not null,
  actor_type text not null,
  resource_type text not null,
  resource_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  ip_address text,
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_created_at on audit_logs(created_at desc);

create table if not exists system_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists security_throttles (
  scope text not null,
  subject text not null,
  hits integer not null default 0,
  window_started_at timestamptz not null default now(),
  blocked_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (scope, subject)
);

create table if not exists email_templates (
  name text primary key,
  subject text not null,
  html text not null,
  text text not null,
  updated_at timestamptz not null default now()
);

insert into system_settings(key, value)
values (
  'local_admin_bootstrap',
  jsonb_build_object(
    'allow_create', true,
    'bootstrap_login_enabled', true
  )
)
on conflict (key) do nothing;

insert into system_settings(key, value)
values (
  'smtp',
  jsonb_build_object(
    'host', 'localhost',
    'port', 1025,
    'username', '',
    'password', '',
    'from', 'ROSM Passport <no-reply@localhost>',
    'secure', false
  )
)
on conflict (key) do nothing;

insert into email_templates(name, subject, html, text)
values (
  'register_verification',
  'ROSM通行证验证码',
  '<div style="font-family:Arial,sans-serif;padding:16px"><h2 style="margin:0 0 10px;color:#0b6b61">ROSM通行证</h2><p>您的验证码是：<strong>{{code}}</strong></p><p style="color:#667085">有效期5分钟</p></div>',
  'ROSM通行证验证码: {{code}}，有效期5分钟。'
)
on conflict (name) do nothing;

insert into email_templates(name, subject, html, text)
values (
  'admin_login_verification',
  'ROSM通行证管理员登录验证码',
  '<div style="font-family:Arial,sans-serif;padding:16px"><h2 style="margin:0 0 10px;color:#0b6b61">ROSM通行证管理端</h2><p>您的管理员登录验证码是：<strong>{{code}}</strong></p><p style="color:#667085">有效期5分钟，请勿泄露。</p></div>',
  'ROSM通行证管理员登录验证码: {{code}}，有效期5分钟，请勿泄露。'
)
on conflict (name) do nothing;

insert into email_templates(name, subject, html, text)
values (
  'login_verification',
  'ROSM通行证登录验证码',
  '<div style="font-family:Arial,sans-serif;padding:16px"><h2 style="margin:0 0 10px;color:#0b6b61">ROSM通行证</h2><p>您的登录验证码是：<strong>{{code}}</strong></p><p style="color:#667085">有效期5分钟，请勿泄露。</p></div>',
  'ROSM通行证登录验证码: {{code}}，有效期5分钟，请勿泄露。'
)
on conflict (name) do nothing;

insert into oidc_clients(
  client_id,
  client_secret_hash,
  redirect_uris,
  scopes,
  grant_types,
  is_confidential,
  is_active
)
values (
  'first_party_web',
  null,
  array['http://localhost:5173/callback']::text[],
  array['openid', 'profile', 'email', 'phone']::text[],
  array['authorization_code', 'refresh_token']::text[],
  false,
  true
)
on conflict (client_id) do nothing;

create table if not exists user_webauthn_credentials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  credential_id text not null unique,
  public_key text not null,
  counter bigint not null default 0,
  transports text[] not null default '{}'::text[],
  device_type text,
  backed_up boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_webauthn_credentials_user on user_webauthn_credentials(user_id);

create table if not exists user_webauthn_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  email text,
  purpose text not null,
  challenge text not null,
  rp_id text not null,
  origin text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_webauthn_challenges_lookup on user_webauthn_challenges(purpose, user_id, email, created_at desc);
