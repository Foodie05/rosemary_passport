# Rosemary Epass 0.10.0 验证记录

日期：2026-10-14。规范 Forma 1.2.0，官方 SDK 0.4.0，提交 `311a81de1651ba049d3acd476725390de38aacc2`。官网保留 React 18.3.1。版本、来源和 SHA-256 见 `web/src/design/manifest.json`。

## 产品调整

按产品负责人最新要求，视觉名称使用 **Rosemary Epass**，保留绿色主色。Epass 产品徽记在官方拱形基础上增加底部圆角、同色系侧面和阴影层次。其几何来自 `epass-mark.json`，生成网站图标、服务端 SVG 与 Flutter 绘制代码；母品牌 PNG 未改动。品牌组合按官方比例垂直居中。协议复选框保留 44px 操作区，首行文案与复选框居中对齐。

## 已执行检查

- Web：45 项测试通过，生产构建通过。使用官方校验器检查每个主题全部 24 个角色和 22 对对比度；验证三个官方发布包与母品牌图片 SHA-256。
- Flutter：38 项测试通过，静态分析通过。验证输入即时反馈、自动填充/IME 编辑状态、协议接受/拒绝/取消、重复请求、MFA 验证码焦点、200% 字号、明暗颜色及字标居中。
- 服务端：135 项本地测试通过、12 项 PostgreSQL 用例未在本地启用；生产路由构建及静态分析通过。邮件默认模板兼容检查覆盖旧种子模板升级与自定义模板保留。
- 独立消费应用：Flutter 3.44.8 / Dart 3.12.2，通过 path 依赖接入 SDK，Dart bundle 与 iOS 模拟器应用构建通过。此机 Xcode 27 要求模拟器目标至少 iOS 15；将消费样例的 Runner/Pods 目标设为 15 后完成编译，未改变 SDK 对外平台声明。
- 浏览器：Codex In-app Browser，桌面 1440px 和 320px。登录、注册、账户、管理看板、用户、服务、安全、OIDC、状态、协议管理、OIDC 文档、SDK 文档、条款、封禁页均执行布局检查；账户弹窗和下拉框检查键盘操作。页面预览使用本地模拟数据。
- 在真实 App 组件的模拟请求环境中验证：未接受协议不发验证码请求；拒绝保留手机号并恢复操作按钮焦点；接受后只产生一次验证码请求。注册输入 `orchid` 即时报长度不足，`orchid-willow` 即时报符合要求。
- 浏览器动效验收 23 项通过：180ms 无位移标签淡入、当前帧中断、减少动态效果、260/160ms 弹窗、220/180ms 抽屉、真实退出后焦点恢复、300ms 加载延迟、1200ms 双折面加载、结束停止、220ms/6px 页面切换及快速导航。

## 可复验入口与附件

启动 `web` 的 Vite 开发服务器后，打开 `tests/browser/motion.html`，点击“运行动效验收”；每次完整运行前重新加载。页面预览在 `tests/browser/forma.html?view=account`，可选 register、dashboard、users、service、security、oidc、status、legal、docs、flutter、terms、banned。协议测试在 `tests/browser/legal-consent.html`，所有文档均为无效力的测试内容，所有请求在页面内模拟。

发布附件包含动效与布局 JSON、验证清单及关键截图。输出目录不进入源码。生成契约检查执行 `python3 scripts/sync_epass_tokens.py`，重新生成后 Git diff 应为空；该步骤也进入 Web CI。

## 范围与限制

本次未执行生产部署、真机验证、Android APK 构建、Safari/Firefox 或 VoiceOver/TalkBack 人工验收。自动填充测试验证原生字段提示和编辑状态；未向真实系统密码管理器保存凭据。浏览器人工验证以模拟账户/管理数据为准，真实数据库集成与覆盖率由 GitHub CI 门禁验证。上游组件后台暂停逻辑随包固定；未把本地模拟检查称作真实 OS 后台切换验收。

SDK 原有 `Rosm*` API、OIDC 协议、回调及存储键保持兼容。官方受控输入不暴露自动填充/IME 参数时使用原生编辑器适配，采用相同顶部标签、颜色和圆角。升级要求和接入代码见 SDK README。自定义邮件模板不会被替换；三个精确匹配的旧默认模板在渲染时采用新样式，不重写数据库中用户的模板。
