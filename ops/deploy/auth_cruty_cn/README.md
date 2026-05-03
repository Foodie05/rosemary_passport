# auth.cruty.cn Deployment

这个目录是生产部署模板。

- 后端容器通过 `127.0.0.1:8091` 暴露，仅供服务器本机反向代理访问
- 前端不会容器化，打包后的静态文件位于 `frontend/dist/`，可直接交给 Apache 托管到 `https://auth.cruty.cn`
- 发布包会在前端目录内附带 `.htaccess`，将所有 SPA 路由回退到 `index.html`
- `LOCAL_ADMIN_EMAIL` / `LOCAL_ADMIN_PASSWORD` / `LOCAL_ADMIN_NICKNAME` 用于首次引导管理员
- `LOCAL_ADMIN_EMAIL` 必须使用保留域名 `@rosm.local`，例如 `bootstrap-admin@rosm.local`
- 首次管理员登录后，需要在账号页绑定正式邮箱；绑定成功后，应用会永久关闭 bootstrap 登录，这组配置之后自然失效

部署时把打包脚本生成的 release 目录上传到服务器：

- 用 Apache 指向 `frontend/dist/` 作为 `auth.cruty.cn` 的站点根目录
- 用 Apache 反向代理 `apiauth.cruty.cn` 到 `http://127.0.0.1:8091`
- 首次部署可在 release 目录中直接启动后端和数据库：

```bash
docker compose up -d --build
```

- 后续更新建议上传新的发布包并在解压后的目录执行：

```bash
./deploy.sh /absolute/path/to/current-release /absolute/path/to/apache-web-root
```

- 例如：

```bash
./deploy.sh /www/wwwroot/rosemary_passport /www/wwwroot/auth.cruty.cn
```

- `deploy.sh` 会自动备份当前版本、保留线上 `.env`、同步新文件、覆盖发布 Apache 前端静态文件并重建容器
- Apache 前端目录本身就是最终站点目录，`deploy.sh` 会直接覆盖这个目录
- 如果不提供 Apache 前端目录，脚本会直接报错退出，避免出现“后端已更新但前端还是旧版”的错配

本地也提供了一键远程部署脚本：

```bash
./scripts/deploy_auth_cruty_cn.sh
```

如果需要自定义目标，可以传参：

```bash
./scripts/deploy_auth_cruty_cn.sh root@cruty.cn /www/wwwroot/auth /www/wwwroot/auth/auth_cruty_cn_release /www/wwwroot/auth.cruty.cn
```
