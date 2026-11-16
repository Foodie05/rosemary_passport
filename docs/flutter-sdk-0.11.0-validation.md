# Rosemary Epass Flutter SDK 0.11.0 验收

日期：2026-11-14。交付方式为仓库固定标签 `v0.11.0` 和 GitHub Release，不发布到 pub.dev。完整 CHANGELOG 保留此前版本记录。

## 累计内容

- Forma 1.3 / 官方 rosemary_ui 0.5.0，源提交 `340d2f4531ea0f1e16d62537b02124e5823d8fa2`。官方源码与许可证完整随包提供；发布归档 SHA256 为 `b179c3f464f60a26a5a9d0c819b09ac68bf0f7c5ee570bd0a74e12c8eb9ffd38`。
- 45 个成对语义角色使用官方 HCT 配方生成。原生 controller、选区、autofill 和 IME 适配保留；新密码遵循 8–32 位 ASCII、至少两类、不含空格，历史密码登录不套用新建策略。
- 手机号与邮箱合并验证码登录，本地识别后再请求 CAPTCHA/发码，保留单独启用方法的配置。版本绑定协议、注册交接、原生 MFA、会话刷新、OIDC PKCE 和服务端交接保持兼容。
- 登录标签滑入滑出并淡入淡出，线性调整内容高度；离场视觉不接受指针、焦点和辅助技术操作。卡片高度等于当前内容及内边距，空间充足时纵向居中，窄屏或键盘压缩时可滚动；减少动态即时切换。
- 账户设置同组共用容器，资料左对齐、长文本省略。邮箱只保留首次非空失焦后的错误反馈，删除常驻示例。
- 新增 `RosmStepUpProof`、当前安全因子元数据及已绑定方式的验证码/通行密钥选项接口。内置个人账户更改需选择另一种已绑定方式，目标邮箱/手机验证码独立保留；选择变化和拒绝操作清除旧证明。服务器继续负责实际校验。管理员角色赋权接口仍只允许当前 admin 加一种实际 MFA，未由 SDK UI 放宽。

## 自动化验证

- SDK：`flutter analyze` 无问题；`flutter test` 56 项通过、无跳过。新增本地识别、窄屏实际登录发码路由、自然高度及居中、动效中断与离场隔离、减少动态、证明序列化、旧参数兼容、因子排除/切换清理，以及实际账户弹窗失败反馈测试。
- 官方 vendored SDK：28 项测试通过、无跳过，源码未修改。
- `dart run build_runner build` 无生成漂移；`scripts/check_rosemary_sdk.py` 验证源归档、展开内容和轮廓适配器一致。
- Web：74 项测试与生产构建通过；SDK 安装代码与整份 Markdown 文档均指向固定标签。
- 现有 320px、200% 字体、明暗主题、IME、autofill、协议门禁、MFA 键盘焦点和 refresh 单次轮换回归均保留。

## 接入与边界

Flutter 3.44.8+ / Dart 3.12.2+。依赖使用 `ref: v0.11.0` 和 `path: packages/rosm_passport_flutter`，再运行 `flutter pub get`；详见包 README 的升级与按次验证示例。

原生通行密钥 UI 仍需接入方提供可信平台实现；SDK 不伪造原生凭据。真实 iOS/Android、平台通行密钥、VoiceOver/TalkBack 与实际第三方 CAPTCHA 未作为本次自动化验收结果。所有 SDK HTTP 测试均为模拟服务，没有连接生产账户或修改生产数据。
