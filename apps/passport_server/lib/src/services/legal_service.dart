import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../repositories/legal_repository.dart';

class LegalSubmission {
  const LegalSubmission({
    required this.terms,
    required this.privacy,
    required this.accepted,
  });

  factory LegalSubmission.fromJson(Map<String, dynamic> json) =>
      LegalSubmission(
        terms: int.tryParse('${json['terms_version'] ?? ''}'),
        privacy: int.tryParse('${json['privacy_version'] ?? ''}'),
        accepted: json['accepted_legal'] == true,
      );

  final int? terms;
  final int? privacy;
  final bool accepted;
}

class LegalValidation {
  const LegalValidation.valid(this.terms, this.privacy) : ok = true;
  const LegalValidation.invalid(this.terms, this.privacy) : ok = false;

  final bool ok;
  final Map<String, dynamic> terms;
  final Map<String, dynamic> privacy;

  Map<String, dynamic> get publicBundle => {
    'terms': _publicDocument(terms),
    'privacy': _publicDocument(privacy),
  };

  static Map<String, dynamic> _publicDocument(Map<String, dynamic> value) => {
    'id': value['id'],
    'type': value['type'],
    'version': value['version'],
    'title': value['title'],
    'published_at': value['published_at'],
  };
}

class LegalService {
  LegalService(this._repository, this._config);

  final LegalRepository _repository;
  final AppConfig _config;
  Future<void>? _initialization;

  static const companyName = 'Rosemary Island LLC';
  static const contactEmail = 'info@rosemaryisland.pro';

  Future<void> ensureInitialDocuments() =>
      _initialization ??= _ensureInitialDocuments();

  Future<void> _ensureInitialDocuments() async {
    await _ensureInitial('terms', 'ROSM Pass 使用条款', _initialTerms);
    await _ensureInitial('privacy', 'ROSM Pass 隐私政策', _initialPrivacy);
  }

  Future<void> _ensureInitial(String type, String title, String content) async {
    if (await _repository.current(type) != null) return;
    final draft = await _repository.saveDraft(
      type: type,
      title: title,
      content: content,
      actorId: '00000000-0000-0000-0000-000000000000',
    );
    await _repository.publish(
      documentId: draft['id'].toString(),
      actorId: '00000000-0000-0000-0000-000000000000',
    );
  }

  Future<Map<String, dynamic>> currentBundle({
    bool includeContent = true,
  }) async {
    await ensureInitialDocuments();
    final terms = await _repository.current('terms');
    final privacy = await _repository.current('privacy');
    if (terms == null || privacy == null) {
      throw StateError('Published legal documents are unavailable.');
    }
    if (includeContent) return {'terms': terms, 'privacy': privacy};
    return {
      'terms': LegalValidation._publicDocument(terms),
      'privacy': LegalValidation._publicDocument(privacy),
    };
  }

  Future<LegalValidation> validate(LegalSubmission submission) async {
    await ensureInitialDocuments();
    final terms = await _repository.current('terms');
    final privacy = await _repository.current('privacy');
    if (terms == null || privacy == null) {
      throw StateError('Published legal documents are unavailable.');
    }
    final matches =
        submission.accepted &&
        submission.terms == terms['version'] &&
        submission.privacy == privacy['version'];
    return matches
        ? LegalValidation.valid(terms, privacy)
        : LegalValidation.invalid(terms, privacy);
  }

  Future<void> record({
    required String userId,
    required LegalValidation validation,
    required String context,
    required String? ip,
    required String? userAgent,
  }) {
    if (!validation.ok) throw StateError('Legal acceptance is not current.');
    return _repository.recordAcceptance(
      userId: userId,
      termsId: validation.terms['id'].toString(),
      privacyId: validation.privacy['id'].toString(),
      context: context,
      ipHash: _hashOptional(ip),
      userAgentHash: _hashOptional(userAgent),
    );
  }

  Future<bool> hasAcceptedCurrent(String userId) =>
      _repository.hasAcceptedCurrent(userId);

  String? _hashOptional(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final key = utf8.encode(_config.jwtBindingKey);
    return Hmac(sha256, key).convert(utf8.encode(normalized)).toString();
  }

  static const _initialTerms = '''ROSM Pass 使用条款
版本：1
生效日期：首次发布之日

本使用条款（“本条款”）是您与 Rosemary Island LLC（在美国怀俄明州注册成立，以下简称“我们”）之间就访问和使用 ROSM Pass 身份认证、账户、通行密钥、多因素认证、OpenID Connect（OIDC）授权及相关服务（统称“服务”）订立的具有约束力的协议。点击同意、注册或登录即表示您已阅读、理解并同意本条款及同版隐私政策。

1. 资格与账户
您应具备订立本协议所需的法定能力。未满十三周岁者不得使用服务；未达到所在地法定成年年龄者应取得父母或法定监护人同意。您必须提供真实、准确、合法的信息，妥善保护密码、验证码、通行密钥、验证器及设备，并对账户内发生的活动负责。发现未经授权使用时，应立即联系 info@rosemaryisland.pro。

2. 服务内容与授权
ROSM Pass 提供统一身份认证、账户资料管理、邮箱或手机号验证、密码与通行密钥登录、多因素认证、OIDC 授权、会话管理和安全审计。第三方应用仅可在其登记的回调地址和获准范围内请求信息。您应在授权页面审慎确认应用、权限和范围；第三方应用自身的服务、内容与行为由其运营者负责。

3. 可接受使用规范
您不得：违反法律法规或他人权利；冒用身份、买卖或出租账户；绕过认证、验证码、限流、权限或安全控制；扫描、攻击、干扰、逆向、抓取或超负荷使用服务；上传恶意代码；利用服务实施欺诈、骚扰、垃圾信息、侵权、违法访问或其他有害活动；获取、传播或尝试推断其他用户数据；协助任何人从事上述行为。

4. 处置、限制与封禁
为维护安全、合规、服务稳定或保护我们、用户及第三方权益，我们可在合理判断下调查活动、限制功能、撤销令牌或授权、暂停或永久封禁账户、保留相关日志，并在法律要求时配合主管机关。对于违反本条款、ROSM Pass 使用规范、法律法规或造成安全风险的账户，我们可不经预先通知采取紧急措施。账户被限制或封禁可能导致您无法登录 ROSM Pass 及依赖该身份的第三方服务、数据或权益；在适用法律允许的最大范围内，由此产生的损失、访问中断、第三方后果或其他问题由您自行承担，Rosemary Island LLC 不承担责任。您可通过 info@rosemaryisland.pro 提供账户信息、事实说明和申诉理由；申诉不保证恢复账户。

5. 服务变更与协议更新
我们可改进、修改、暂停或终止全部或部分服务。管理员发布更新后的条款即形成新版本；在需要时，您必须再次明确同意后方可继续注册、登录或使用服务。若您不同意新版，应停止使用服务。

6. 知识产权
服务的软件、界面、标识、文档及相关成果归 Rosemary Island LLC 或其许可方所有。本条款仅授予您为正常使用服务所必需的有限、可撤销、不可转让、非独占许可，不转让任何知识产权。

7. 第三方服务
服务可能依赖云基础设施、对象存储、邮件、短信、人机验证、操作系统凭据管理器及第三方 OIDC 应用。第三方服务可能受其自身条款和隐私政策约束。我们不控制第三方服务，亦不对其可用性、内容、安全性或行为作保证。

8. 免责声明
在适用法律允许的最大范围内，服务按“现状”和“可用”提供。我们不作任何明示、默示或法定保证，包括适销性、特定用途适用性、不侵权、持续可用、无错误、无中断、绝对安全或数据绝不丢失。身份认证和安全措施只能降低风险，不能消除所有攻击、设备故障、网络问题、第三方故障或不可抗力。

9. 责任限制
在适用法律允许的最大范围内，Rosemary Island LLC 及其成员、管理人员、雇员、承包商和许可方不对任何间接、附带、特殊、惩罚性、示范性或后果性损害，或利润、收入、商誉、数据、业务机会、账户访问或第三方服务权益的损失负责。我们的累计责任以导致索赔事件前十二个月您就 ROSM Pass 实际支付的费用与一百美元（USD 100）中的较高者为限。本条不排除法律禁止排除或限制的责任。

10. 赔偿
在法律允许范围内，因您违反本条款、违法使用服务、侵犯第三方权利或通过账户实施的行为而产生的第三方索赔、损失、罚款和合理费用，您应赔偿并使 Rosemary Island LLC 免受损害，但以该等责任依法可由您承担为限。

11. 适用法律与争议
本条款受美国怀俄明州法律管辖，不适用其法律冲突规则；但您所在地不可排除的强制性消费者或个人信息保护法律仍然适用。除适用法律另有强制规定外，争议应提交怀俄明州有管辖权的州法院或联邦法院解决，双方同意该等法院的管辖与审判地。

12. 其他
本条款与隐私政策构成双方关于服务的完整协议。某一条款无效不影响其余条款。我们未立即行使权利不构成放弃。未经我们书面同意，您不得转让本协议；我们可在重组、合并、资产转让或依法经营时转让本协议。

13. 联系方式
Rosemary Island LLC（美国怀俄明州）
电子邮箱：info@rosemaryisland.pro
''';

  static const _initialPrivacy = '''ROSM Pass 隐私政策
版本：1
生效日期：首次发布之日

本隐私政策说明 Rosemary Island LLC（在美国怀俄明州注册成立，以下简称“我们”）在运营 ROSM Pass 时如何收集、使用、保存、共享和保护个人信息。点击同意、注册或登录即表示您确认已阅读本政策。我们不会通过本政策排除您依据适用法律享有的不可放弃权利。

1. 我们处理的信息
我们可能处理：账户标识、邮箱、手机号、昵称、角色、注册和更新时间；密码的不可逆哈希；通行密钥公钥、凭据标识和验证元数据；经加密保存的验证器密钥；邮箱、短信及人机验证记录；登录、授权、撤销、会话、风控、设备和浏览器信息；IP 地址或其脱敏/哈希表示、请求时间、规范化访问路径、状态码和安全事件；OIDC 客户端、授权范围、回调地址及授权记录；您向我们提交的支持、申诉和合规材料。我们不在行为日志中记录密码、验证码明文、令牌、客户端密钥或完整请求体。

2. 处理目的与依据
我们为创建和维护账户、验证身份、签发和撤销令牌、完成 OIDC 授权、提供安全功能、发送必要通知、检测欺诈和攻击、限流、调查滥用、封禁或恢复账户、维护备份与灾难恢复、改进容量和可靠性、履行合同、遵守法律义务及建立或抗辩法律请求而处理信息。处理依据可能包括履行合同、您的同意、我们的合法利益以及法律义务；适用法律要求单独同意时，我们将另行取得。

3. 信息共享与受托处理
我们仅在提供服务所必需的范围内向基础设施和对象存储、数据库托管、邮件、短信、人机验证、安全、监控和专业顾问等服务提供商披露信息，并要求其采取适当保护措施。经您授权的 OIDC 应用可获得授权范围内的账户信息。我们也可能为遵守法律程序、保护安全与合法权益、调查违法行为，或在合并、融资、重组、资产转让时披露必要信息。我们不以出售个人信息为主要业务。

4. 跨境处理
Rosemary Island LLC 位于美国，服务提供商和用户可能位于不同国家或地区，因此信息可能被跨境访问、传输、备份或处理。我们将根据适用法律采取合同、加密、访问控制和其他必要措施；若特定跨境传输需要单独同意、标准合同、安全评估或其他机制，我们将依法办理。

5. 保存期限
我们仅在实现本政策目的、维持账户和安全、解决争议、执行协议及满足法律要求所需期间保存信息。账户数据通常保存至账户删除或服务终止后合理期限；安全、审计、封禁、协议接受及合规记录可能为防止滥用、证明授权或履行法律义务而保存更长时间。加密备份按照备份轮换周期到期删除；法律保全要求可能暂停删除。

6. 安全措施
我们采用传输加密、密码哈希、敏感配置加密、密钥轮换、最小权限、非 root 容器、访问控制、日志脱敏、审计哈希链、限流、备份和恢复测试等合理措施。任何系统均无法保证绝对安全；您也应保护设备、邮箱、手机号、密码、通行密钥和验证器。

7. 您的权利
依据适用法律，您可能有权查询、复制、更正、补充、删除或限制处理个人信息，撤回同意，注销账户，对自动化或账户处置提出解释和申诉，以及向主管机关投诉。为保护账户，我们可能要求验证身份。某些信息因安全、反欺诈、审计、法律保全或履行法定义务而无法立即删除。

8. 儿童与未成年人
ROSM Pass 不面向十三周岁以下儿童，我们不会故意收集其个人信息。未达到所在地法定成年年龄的用户应在父母或监护人指导和同意下使用。若您认为儿童未经适当授权向我们提供信息，请联系我们。

9. Cookie 与本地存储
我们使用严格限定的安全 Cookie、本地存储或系统安全存储来维持会话、记住非敏感登录偏好、保存主题设置和完成安全跳转。认证 Cookie 采用 HttpOnly、Secure 和适当的 SameSite 限制；我们不使用这些技术进行跨站广告追踪。

10. 自动化安全判断
我们可能根据验证码、请求频率、认证失败、令牌重放、异常路径和其他安全信号自动限制请求或触发额外验证。对账户封禁等重大处置，我们保留人工复核和申诉渠道。

11. 政策更新
管理员发布更新后的政策即形成新版本。重大变更或适用法律要求时，我们会在服务中提示，并要求您在后续注册、登录或继续使用前重新明确同意。历史版本和同意记录将为合规证明而保留。

12. 法律适用
本政策及与隐私有关的合同问题受美国怀俄明州法律管辖，但不影响适用于您的不可排除的个人信息保护、数据安全和消费者保护法律。若您位于中华人民共和国境内，我们将依适用的《中华人民共和国个人信息保护法》等强制性规定处理相关个人信息。

13. 联系我们
个人信息请求、账户申诉、安全报告或其他问题请联系：
Rosemary Island LLC（美国怀俄明州）
电子邮箱：info@rosemaryisland.pro
''';
}
