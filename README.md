# ROSM通行证

ROSM通行证是一个面向多应用接入的安全单点登录系统，后端基于 `dart_frog`，支持标准 OIDC 端点，并包含用户中心与管理后台前端。

## 核心能力

- 安全密码存储：`Argon2id`
- 安全传输：默认要求 HTTPS，附加 HSTS/CSP/NoSniff 等响应头
- 双Key JWT：`RS256` 签名 + 二次 `HMAC-SHA256` 绑定校验（`sig2`）
- OIDC 端点：
  - `/.well-known/openid-configuration`
  - `/oidc/authorize`
  - `/oidc/token`
  - `/oidc/userinfo`
  - `/oidc/jwks`
  - `/oidc/introspect`
  - `/oidc/revoke`
- 注册链路：邮箱 + 邮箱验证码，验证码发送前强制 `captcha`
- 手机号验证码：支持阿里云号码认证短信发送与校验接口（可选启用）
- 后台能力：用户管理、角色管理、审计日志

## 目录结构

- `apps/passport_server`: Dart Frog 服务端
- `ops/postgres/init/001_init.sql`: PostgreSQL 初始化脚本
- `web`: 统一前端（登录/注册/用户中心/管理后台）

## 快速启动

### 一键本地运行（推荐）

```bash
cd /Users/tianyue/Documents/Projects/rosemary_passport
./run_local.sh
```

`run_local.sh` 会先清理占用端口，再自动打开两个终端窗口前台运行：
- 后端：`dart_frog dev`（便于热更新与观察日志）
- 前端：`python3 -m http.server 5173`

首次运行会自动创建本地管理员并输出到日志与控制台：

- 账号凭证文件：[.local/admin_credentials.env](/Users/tianyue/Documents/Projects/rosemary_passport/.local/admin_credentials.env)
- 启动日志文件：[.local/bootstrap.log](/Users/tianyue/Documents/Projects/rosemary_passport/.local/bootstrap.log)

停止：

```bash
./stop_local.sh
```

### 手动启动

1. 准备 PostgreSQL（建议开启 TLS）。
2. 执行数据库初始化脚本 `ops/postgres/init/001_init.sql`。
3. 复制 `apps/passport_server/.env.example` 为 `.env` 并填充真实密钥。
4. 进入服务目录并启动：

```bash
cd /Users/tianyue/Documents/Projects/rosemary_passport/apps/passport_server
dart pub get
dart run dart_frog_cli:dart_frog build
PORT=8080 dart run build/bin/server.dart
```

5. 前端在 `web/` 目录，默认调用 `http://localhost:8080`，可用任意静态文件服务打开 `index.html`。

### hCaptcha 配置

前端 `sitekey` 配置在 [web/config.js](/Users/tianyue/Documents/Projects/rosemary_passport/web/config.js)：

```js
window.ROSM_CONFIG = {
  apiBase: 'http://localhost:8080',
  hcaptchaSiteKey: '你的_hcaptcha_sitekey',
};
```

后端 `secret` 配置在 `apps/passport_server/.env`：

```env
HCAPTCHA_SECRET=你的_hcaptcha_secret
```

## 必做的生产安全项

- 使用受信任证书，禁止明文 HTTP。
- 将 `JWT_PRIVATE_KEY_PEM` 和 `JWT_BINDING_KEY` 存储在密钥管理系统。
- 将 `EmailService` 替换为成熟邮件服务商 SDK（SES/Postmark/Mailgun）。
- 对 `auth`、`oidc/token`、`oidc/introspect` 增加限流与风控策略。
- 定期轮换签名密钥并发布新 `kid`。

## 开源安全组件复用

- `dart_frog` / `dart_frog_auth`
- `argon2`
- `dart_jsonwebtoken`
- `jose`
- `postgres`
- `http`
