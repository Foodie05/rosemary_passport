// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/index.dart' as index;
import '../routes/oidc/userinfo.dart' as oidc_userinfo;
import '../routes/oidc/token.dart' as oidc_token;
import '../routes/oidc/revoke.dart' as oidc_revoke;
import '../routes/oidc/jwks.dart' as oidc_jwks;
import '../routes/oidc/introspect.dart' as oidc_introspect;
import '../routes/oidc/authorize.dart' as oidc_authorize;
import '../routes/api/v1/public/config.dart' as api_v1_public_config;
import '../routes/api/v1/me/send-password-reset-code.dart' as api_v1_me_send_password_reset_code;
import '../routes/api/v1/me/send-bind-email-code.dart' as api_v1_me_send_bind_email_code;
import '../routes/api/v1/me/reset-password.dart' as api_v1_me_reset_password;
import '../routes/api/v1/me/index.dart' as api_v1_me_index;
import '../routes/api/v1/me/bind-email.dart' as api_v1_me_bind_email;
import '../routes/api/v1/me/webauthn/register/verify.dart' as api_v1_me_webauthn_register_verify;
import '../routes/api/v1/me/webauthn/register/options.dart' as api_v1_me_webauthn_register_options;
import '../routes/api/v1/me/webauthn/credentials/index.dart' as api_v1_me_webauthn_credentials_index;
import '../routes/api/v1/me/webauthn/credentials/[credentialId].dart' as api_v1_me_webauthn_credentials_$credential_id;
import '../routes/api/v1/me/authenticator/verify.dart' as api_v1_me_authenticator_verify;
import '../routes/api/v1/me/authenticator/setup.dart' as api_v1_me_authenticator_setup;
import '../routes/api/v1/auth/send-login-code.dart' as api_v1_auth_send_login_code;
import '../routes/api/v1/auth/send-email-login-code.dart' as api_v1_auth_send_email_login_code;
import '../routes/api/v1/auth/send-code.dart' as api_v1_auth_send_code;
import '../routes/api/v1/auth/register.dart' as api_v1_auth_register;
import '../routes/api/v1/auth/refresh.dart' as api_v1_auth_refresh;
import '../routes/api/v1/auth/password-factors.dart' as api_v1_auth_password_factors;
import '../routes/api/v1/auth/logout.dart' as api_v1_auth_logout;
import '../routes/api/v1/auth/login.dart' as api_v1_auth_login;
import '../routes/api/v1/auth/login-code-status.dart' as api_v1_auth_login_code_status;
import '../routes/api/v1/auth/email-login.dart' as api_v1_auth_email_login;
import '../routes/api/v1/auth/captcha.dart' as api_v1_auth_captcha;
import '../routes/api/v1/auth/admin-login-code.dart' as api_v1_auth_admin_login_code;
import '../routes/api/v1/auth/webauthn/verify.dart' as api_v1_auth_webauthn_verify;
import '../routes/api/v1/auth/webauthn/options.dart' as api_v1_auth_webauthn_options;
import '../routes/api/v1/admin/audits.dart' as api_v1_admin_audits;
import '../routes/api/v1/admin/users/index.dart' as api_v1_admin_users_index;
import '../routes/api/v1/admin/users/[id]/roles.dart' as api_v1_admin_users_$id_roles;
import '../routes/api/v1/admin/users/[id]/index.dart' as api_v1_admin_users_$id_index;
import '../routes/api/v1/admin/settings/smtp-test.dart' as api_v1_admin_settings_smtp_test;
import '../routes/api/v1/admin/settings/index.dart' as api_v1_admin_settings_index;
import '../routes/api/v1/admin/settings/hcaptcha-test.dart' as api_v1_admin_settings_hcaptcha_test;
import '../routes/api/v1/admin/settings/templates/index.dart' as api_v1_admin_settings_templates_index;
import '../routes/api/v1/admin/settings/templates/[name]/index.dart' as api_v1_admin_settings_templates_$name_index;
import '../routes/api/v1/admin/oidc/clients/index.dart' as api_v1_admin_oidc_clients_index;
import '../routes/api/v1/admin/oidc/clients/[id]/index.dart' as api_v1_admin_oidc_clients_$id_index;
import '../routes/.well-known/openid-configuration.dart' as well_known_openid_configuration;

import '../routes/_middleware.dart' as middleware;
import '../routes/api/v1/me/_middleware.dart' as api_v1_me_middleware;
import '../routes/api/v1/admin/_middleware.dart' as api_v1_admin_middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/', (context) => buildHandler()(context))
    ..mount('/oidc', (context) => buildOidcHandler()(context))
    ..mount('/api/v1/public', (context) => buildApiV1PublicHandler()(context))
    ..mount('/api/v1/me', (context) => buildApiV1MeHandler()(context))
    ..mount('/api/v1/me/webauthn/register', (context) => buildApiV1MeWebauthnRegisterHandler()(context))
    ..mount('/api/v1/me/webauthn/credentials', (context) => buildApiV1MeWebauthnCredentialsHandler()(context))
    ..mount('/api/v1/me/authenticator', (context) => buildApiV1MeAuthenticatorHandler()(context))
    ..mount('/api/v1/auth', (context) => buildApiV1AuthHandler()(context))
    ..mount('/api/v1/auth/webauthn', (context) => buildApiV1AuthWebauthnHandler()(context))
    ..mount('/api/v1/admin', (context) => buildApiV1AdminHandler()(context))
    ..mount('/api/v1/admin/users', (context) => buildApiV1AdminUsersHandler()(context))
    ..mount('/api/v1/admin/users/<id>', (context,id,) => buildApiV1AdminUsers$idHandler(id,)(context))
    ..mount('/api/v1/admin/settings', (context) => buildApiV1AdminSettingsHandler()(context))
    ..mount('/api/v1/admin/settings/templates', (context) => buildApiV1AdminSettingsTemplatesHandler()(context))
    ..mount('/api/v1/admin/settings/templates/<name>', (context,name,) => buildApiV1AdminSettingsTemplates$nameHandler(name,)(context))
    ..mount('/api/v1/admin/oidc/clients', (context) => buildApiV1AdminOidcClientsHandler()(context))
    ..mount('/api/v1/admin/oidc/clients/<id>', (context,id,) => buildApiV1AdminOidcClients$idHandler(id,)(context))
    ..mount('/.well-known', (context) => buildWellKnownHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildOidcHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/authorize', (context) => oidc_authorize.onRequest(context,))..all('/introspect', (context) => oidc_introspect.onRequest(context,))..all('/jwks', (context) => oidc_jwks.onRequest(context,))..all('/revoke', (context) => oidc_revoke.onRequest(context,))..all('/token', (context) => oidc_token.onRequest(context,))..all('/userinfo', (context) => oidc_userinfo.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1PublicHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/config', (context) => api_v1_public_config.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1MeHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_me_middleware.middleware);
  final router = Router()
    ..all('/bind-email', (context) => api_v1_me_bind_email.onRequest(context,))..all('/reset-password', (context) => api_v1_me_reset_password.onRequest(context,))..all('/send-bind-email-code', (context) => api_v1_me_send_bind_email_code.onRequest(context,))..all('/send-password-reset-code', (context) => api_v1_me_send_password_reset_code.onRequest(context,))..all('/', (context) => api_v1_me_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1MeWebauthnRegisterHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_me_middleware.middleware);
  final router = Router()
    ..all('/options', (context) => api_v1_me_webauthn_register_options.onRequest(context,))..all('/verify', (context) => api_v1_me_webauthn_register_verify.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1MeWebauthnCredentialsHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_me_middleware.middleware);
  final router = Router()
    ..all('/<credentialId>', (context,credentialId,) => api_v1_me_webauthn_credentials_$credential_id.onRequest(context,credentialId,))..all('/', (context) => api_v1_me_webauthn_credentials_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1MeAuthenticatorHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_me_middleware.middleware);
  final router = Router()
    ..all('/setup', (context) => api_v1_me_authenticator_setup.onRequest(context,))..all('/verify', (context) => api_v1_me_authenticator_verify.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AuthHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/admin-login-code', (context) => api_v1_auth_admin_login_code.onRequest(context,))..all('/captcha', (context) => api_v1_auth_captcha.onRequest(context,))..all('/email-login', (context) => api_v1_auth_email_login.onRequest(context,))..all('/login', (context) => api_v1_auth_login.onRequest(context,))..all('/login-code-status', (context) => api_v1_auth_login_code_status.onRequest(context,))..all('/logout', (context) => api_v1_auth_logout.onRequest(context,))..all('/password-factors', (context) => api_v1_auth_password_factors.onRequest(context,))..all('/refresh', (context) => api_v1_auth_refresh.onRequest(context,))..all('/register', (context) => api_v1_auth_register.onRequest(context,))..all('/send-code', (context) => api_v1_auth_send_code.onRequest(context,))..all('/send-email-login-code', (context) => api_v1_auth_send_email_login_code.onRequest(context,))..all('/send-login-code', (context) => api_v1_auth_send_login_code.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AuthWebauthnHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/options', (context) => api_v1_auth_webauthn_options.onRequest(context,))..all('/verify', (context) => api_v1_auth_webauthn_verify.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/audits', (context) => api_v1_admin_audits.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminUsersHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_admin_users_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminUsers$idHandler(String id,) {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/roles', (context) => api_v1_admin_users_$id_roles.onRequest(context,id,))..all('/', (context) => api_v1_admin_users_$id_index.onRequest(context,id,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminSettingsHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/hcaptcha-test', (context) => api_v1_admin_settings_hcaptcha_test.onRequest(context,))..all('/smtp-test', (context) => api_v1_admin_settings_smtp_test.onRequest(context,))..all('/', (context) => api_v1_admin_settings_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminSettingsTemplatesHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_admin_settings_templates_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminSettingsTemplates$nameHandler(String name,) {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_admin_settings_templates_$name_index.onRequest(context,name,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminOidcClientsHandler() {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_admin_oidc_clients_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiV1AdminOidcClients$idHandler(String id,) {
  final pipeline = const Pipeline().addMiddleware(api_v1_admin_middleware.middleware);
  final router = Router()
    ..all('/', (context) => api_v1_admin_oidc_clients_$id_index.onRequest(context,id,));
  return pipeline.addHandler(router);
}

Handler buildWellKnownHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/openid-configuration', (context) => well_known_openid_configuration.onRequest(context,));
  return pipeline.addHandler(router);
}

