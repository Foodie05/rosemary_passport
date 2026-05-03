import { PAGE_META, SECURITY_FIELDS } from '../constants';
import { cleanDisplayName, formatAnyDate, getInitial } from '../utils';
import { EmptyState, Field, InfoPill, InfoTile, KeyValueList, Panel } from './ui';

function countEnabledClients(oidcClients) {
  return oidcClients.filter((client) => client.is_active !== false).length;
}

function normalizeLines(value) {
  return `${value || ''}`
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean);
}

function fillOidcFormFromClient(client, setOidcForm) {
  setOidcForm({
    client_id: client.client_id || '',
    redirect_uris: (client.redirect_uris || []).join('\n'),
    scopes: (client.scopes || []).join('\n'),
    grant_types: (client.grant_types || []).join('\n'),
    client_secret: '',
    is_confidential: Boolean(client.is_confidential),
    is_active: client.is_active !== false,
  });
}

function describeAudit(entry) {
  const detailPairs = [
    ['操作者', entry.email || entry.actor || entry.user_email],
    ['目标对象', entry.target || entry.resource || entry.entity],
    ['来源 IP', entry.ip || entry.ip_address],
    ['结果', entry.result || entry.status],
  ].filter(([, value]) => value);

  return detailPairs.length
    ? detailPairs
    : [['记录 ID', entry.id || '未提供'], ['事件类型', entry.type || entry.action || '未知']];
}

function buildRoleSummary(users) {
  const counts = users.reduce((result, user) => {
    (user.roles || []).forEach((role) => {
      result[role] = (result[role] || 0) + 1;
    });
    return result;
  }, {});

  return Object.entries(counts).sort((left, right) => right[1] - left[1]);
}

function buildOverviewActions({ isAdmin, mustBindEmail, systemSettings, templates, oidcClients, discovery }) {
  const items = [];

  if (mustBindEmail) {
    items.push({
      title: '先完成邮箱绑定',
      body: '高级管理能力已被收敛，完成资料更新后才能继续操作系统配置与用户管理。',
      tone: 'warn',
    });
  }

  if (isAdmin && !systemSettings) {
    items.push({
      title: '系统配置尚未加载',
      body: '建议先进入系统配置页检查 SMTP、验证码与限流策略是否齐全。',
      tone: 'neutral',
    });
  }

  if (isAdmin && templates.length === 0) {
    items.push({
      title: '通知模板为空',
      body: '邮件模板缺失会直接影响注册、登录验证码与安全通知的可交付性。',
      tone: 'warn',
    });
  }

  if (oidcClients.length === 0) {
    items.push({
      title: '还没有接入客户端',
      body: '如果系统即将对外开放接入，建议先完成首个 OIDC 客户端配置并验证回调地址。',
      tone: 'neutral',
    });
  }

  if (!discovery) {
    items.push({
      title: '协议发现文档未校验',
      body: '进入开放接入页后刷新 discovery，确认 issuer 与授权端点已经对外可用。',
      tone: 'neutral',
    });
  }

  if (!items.length) {
    items.push({
      title: '系统状态稳定',
      body: '核心配置、模板与客户端数据都已具备，当前更适合进入用户、审计与安全策略巡检。',
      tone: 'good',
    });
  }

  return items;
}

export function DashboardScreen({
  page,
  status,
  session,
  mustBindEmail,
  navItems,
  visiblePages,
  navigateTo,
  logout,
  overviewStats,
  systemSettings,
  selectedTemplate,
  discovery,
  oidcClients,
  profileForm,
  setProfileForm,
  saveProfile,
  systemForm,
  setSystemForm,
  saveSystemSettings,
  templates,
  activeTemplate,
  templateForm,
  setTemplateForm,
  saveCurrentTemplate,
  handleTemplateSelect,
  loadDiscovery,
  loadOidcClients,
  safely,
  oidcForm,
  setOidcForm,
  saveOidcClient,
  users,
  loadUsers,
  audits,
  loadAudits,
}) {
  const pageMeta = PAGE_META[page] || PAGE_META.overview;
  const displayNickname = cleanDisplayName(session.user?.nickname, session.user?.email || '-');
  const rawNickname = session.user?.nickname || session.user?.email || '-';
  const isAdmin = (session.user?.roles || []).includes('admin');
  const enabledClientCount = countEnabledClients(oidcClients);
  const roleSummary = buildRoleSummary(users);
  const overviewActions = buildOverviewActions({
    isAdmin,
    mustBindEmail,
    systemSettings,
    templates,
    oidcClients,
    discovery,
  });
  const securityFieldCount = Object.keys(systemSettings?.security || {}).length;
  const criticalEndpoints = [
    ['Issuer', discovery?.issuer],
    ['授权端点', discovery?.authorization_endpoint],
    ['Token 端点', discovery?.token_endpoint],
    ['UserInfo 端点', discovery?.userinfo_endpoint],
    ['JWKS', discovery?.jwks_uri],
  ].filter(([, value]) => value);

  return (
    <section className="dashboard-shell">
      <aside className="dashboard-sidebar">
        <div className="brand-card product-brand">
          <p className="eyebrow">ROSM Passport</p>
          <h2>Admin Console</h2>
          <p>Identity administration</p>
        </div>

        <div className="profile-card">
          <div className="profile-head">
            <div className="avatar-orb">{getInitial(session.user?.email)}</div>
            <div className="profile-copy">
              <h3 className="profile-name" title={rawNickname}>
                {displayNickname}
              </h3>
              <p className="profile-email" title={session.user?.email || '-'}>
                {session.user?.email}
              </p>
            </div>
          </div>
          <div className="account-meta">
            <span>控制台身份</span>
            <strong>{isAdmin ? 'Administrator' : 'Member'}</strong>
          </div>
          <div className="badge-row">
            {(session.user?.roles || []).map((role) => (
              <span key={role} className="role-badge">
                {role}
              </span>
            ))}
          </div>
        </div>

        <div className="sidebar-section-label">工作区</div>
        <nav className="nav-list">
          {navItems.map((item) => (
            <button
              key={item.key}
              className={`nav-button ${page === item.key ? 'active' : ''}`}
              onClick={() => navigateTo(item.key)}
              type="button"
            >
              <span>{item.label}</span>
              <small>{item.title}</small>
            </button>
          ))}
        </nav>

        <div className="sidebar-footer">
          <button className="ghost" onClick={() => navigateTo('profile')} type="button">
            账号与安全
          </button>
          <button className="danger" onClick={() => logout()} type="button">
            退出登录
          </button>
        </div>
      </aside>

      <main className="dashboard-main">
        <section className="hero-panel dashboard-hero">
          <div className="hero-copy">
            <p className="eyebrow">{pageMeta.label}</p>
            <h1>{pageMeta.title}</h1>
            <p className="lede">{pageMeta.description}</p>
          </div>
          <div className="hero-actions hero-actions-grid">
            <InfoPill label="当前状态" value={status.replace('已登录：', '')} />
            <InfoPill label="访问级别" value={isAdmin ? '管理员' : '普通用户'} />
            <InfoPill label="邮箱状态" value={mustBindEmail ? '待绑定' : '已满足'} />
          </div>
        </section>

        {mustBindEmail && (
          <section className="notice-panel">
            <strong>当前账号需要先完成邮箱绑定。</strong>
            <span>系统配置、用户与审计相关能力已临时收敛，完成绑定后将自动恢复完整管理权限。</span>
          </section>
        )}

        {page === 'overview' && (
          <div className="content-stack">
            <section className="stats-grid">
              {overviewStats.map((item) => (
                <article key={item.label} className="stat-card">
                  <span>{item.label}</span>
                  <strong>{item.value}</strong>
                  <p>{item.hint}</p>
                </article>
              ))}
            </section>

            <section className="panel-grid panel-grid-2">
              <Panel title="当前运行状态" description="只保留管理决策真正需要的摘要信息。">
                <div className="insight-list">
                  <InfoTile title="系统配置" value={systemSettings ? '已加载' : '待核验'} tone={systemSettings ? 'good' : 'warn'} />
                  <InfoTile title="模板资产" value={`${templates.length} 套`} tone={templates.length ? 'neutral' : 'warn'} />
                  <InfoTile title="OIDC 客户端" value={`${enabledClientCount}/${oidcClients.length || 0} 启用`} tone={oidcClients.length ? 'neutral' : 'warn'} />
                  <InfoTile title="协议发现" value={discovery ? '可读取' : '未校验'} tone={discovery ? 'good' : 'warn'} />
                </div>
              </Panel>

              <Panel title="建议优先处理" description="根据当前数据状态生成最先该做的动作。">
                <div className="priority-list">
                  {overviewActions.map((item) => (
                    <article key={item.title} className={`priority-card ${item.tone || 'neutral'}`}>
                      <strong>{item.title}</strong>
                      <p>{item.body}</p>
                    </article>
                  ))}
                </div>
              </Panel>
            </section>

            <section className="panel-grid panel-grid-2">
              <Panel title="访问与账号" description="便于确认当前管理身份是否符合预期。">
                <KeyValueList
                  items={[
                    ['当前邮箱', session.user?.email || '-'],
                    ['显示昵称', displayNickname],
                    ['角色集合', (session.user?.roles || []).join(', ') || '-'],
                    ['邮箱绑定要求', mustBindEmail ? '需要处理' : '已满足'],
                  ]}
                />
              </Panel>

              <Panel title="接入准备度" description="从协议与客户端两个层面确认对外开放能力。">
                <KeyValueList
                  items={[
                    ['Discovery 文档', discovery ? '已可读取' : '未加载'],
                    ['启用客户端', `${enabledClientCount} 个`],
                    ['模板数量', `${templates.length} 套`],
                    ['安全策略项', `${securityFieldCount} 条`],
                  ]}
                />
              </Panel>
            </section>

            <section className="panel-grid panel-grid-2">
              <Panel title="已注册客户端" description="优先查看已启用的接入配置。">
                <div className="client-summary-list">
                  {oidcClients.slice(0, 4).map((client) => (
                    <button
                      key={client.client_id}
                      className="entity-card"
                      onClick={() => {
                        fillOidcFormFromClient(client, setOidcForm);
                        navigateTo('oidc');
                      }}
                      type="button"
                    >
                      <div className="row-spread">
                        <strong>{client.client_id}</strong>
                        <span className={`status-dot ${client.is_active === false ? 'off' : 'on'}`}>
                          {client.is_active === false ? '停用' : '启用'}
                        </span>
                      </div>
                      <p>{(client.redirect_uris || []).join(', ') || '未配置 redirect URI'}</p>
                    </button>
                  ))}
                  {!oidcClients.length && <EmptyState title="暂无客户端" body="接入方创建后会出现在这里，可直接跳转到 OIDC 页面继续完善。" />}
                </div>
              </Panel>

              <Panel title="管理入口" description="按管理职责进入对应工作区。">
                <div className="action-grid">
                  {navItems
                    .filter((item) => item.key !== 'overview')
                    .map((item) => (
                      <button key={item.key} className="action-card" onClick={() => navigateTo(item.key)} type="button">
                        <strong>{item.title}</strong>
                        <p>{item.description}</p>
                      </button>
                    ))}
                </div>
              </Panel>
            </section>
          </div>
        )}

        {page === 'profile' && (
          <div className="content-stack">
            <section className="panel-grid panel-grid-2">
              <Panel title="账号信息" description="在不打断当前会话的前提下完成资料与凭证更新。">
                <form className="stack" onSubmit={saveProfile}>
                  <Field label="昵称">
                    <input
                      value={profileForm.nickname}
                      onChange={(event) =>
                        setProfileForm((current) => ({ ...current, nickname: event.target.value }))
                      }
                    />
                  </Field>
                  <Field label="新邮箱">
                    <input
                      type="email"
                      value={profileForm.email}
                      onChange={(event) =>
                        setProfileForm((current) => ({ ...current, email: event.target.value }))
                      }
                    />
                  </Field>
                  <Field label="新密码">
                    <input
                      type="password"
                      value={profileForm.new_password}
                      onChange={(event) =>
                        setProfileForm((current) => ({
                          ...current,
                          new_password: event.target.value,
                        }))
                      }
                    />
                  </Field>
                  <Field label="当前密码">
                    <input
                      type="password"
                      value={profileForm.current_password}
                      onChange={(event) =>
                        setProfileForm((current) => ({
                          ...current,
                          current_password: event.target.value,
                        }))
                      }
                    />
                  </Field>
                  <button type="submit">保存账号设置</button>
                </form>
              </Panel>

              <Panel title="安全状态" description="把会话安全、身份状态与当前权限拆开显示。">
                <div className="insight-list">
                  <InfoTile title="邮箱绑定" value={mustBindEmail ? '待完成' : '已完成'} tone={mustBindEmail ? 'warn' : 'good'} />
                  <InfoTile title="角色数量" value={`${session.user?.roles?.length || 0} 个`} tone="neutral" />
                  <InfoTile title="昵称状态" value={session.user?.nickname ? '已设置' : '未设置'} tone="neutral" />
                  <InfoTile title="当前权限" value={isAdmin ? '管理员' : '标准用户'} tone="neutral" />
                </div>
                <div className="detail-list">
                  <KeyValueList
                    items={[
                      ['登录邮箱', session.user?.email || '-'],
                      ['用户 ID', session.user?.id || '-'],
                      ['会话角色', (session.user?.roles || []).join(', ') || '-'],
                    ]}
                  />
                </div>
              </Panel>
            </section>
          </div>
        )}

        {page === 'system' && visiblePages.system && (
          <div className="content-stack">
            <section className="panel-grid panel-grid-2">
              <Panel title="运行摘要" description="保存前先确认当前系统配置是否完整。">
                <div className="insight-list">
                  <InfoTile title="SMTP Host" value={systemForm.smtp_host || '未配置'} tone={systemForm.smtp_host ? 'good' : 'warn'} />
                  <InfoTile title="发件地址" value={systemForm.smtp_from || '未配置'} tone={systemForm.smtp_from ? 'good' : 'warn'} />
                  <InfoTile
                    title="邮箱验证"
                    value={systemForm.registration_email_verify ? '注册强制验证' : '可跳过验证'}
                    tone={systemForm.registration_email_verify ? 'good' : 'warn'}
                  />
                  <InfoTile title="安全阈值" value={`${SECURITY_FIELDS.length} 项`} tone="neutral" />
                </div>
              </Panel>

              <Panel title="策略提示" description="这些配置最直接影响账号安全与投递可用性。">
                <div className="priority-list">
                  <article className="priority-card neutral">
                    <strong>SMTP 密码将覆盖保存</strong>
                    <p>提交前请确认发信凭证正确，错误配置会影响验证码与安全邮件的发送链路。</p>
                  </article>
                  <article className="priority-card neutral">
                    <strong>限流策略建议保留正整数</strong>
                    <p>过低会影响正常登录，过高则削弱保护能力，建议结合真实流量调参。</p>
                  </article>
                </div>
              </Panel>
            </section>

            <section className="panel-grid">
              <Panel title="系统配置" description="集中维护 SMTP、注册验证和关键风控阈值。">
                <form className="stack" onSubmit={saveSystemSettings}>
                  <div className="form-section-grid">
                    <div className="form-subsection">
                      <h3>注册与验证码</h3>
                      <Field label="hCaptcha Site Key">
                        <input
                          value={systemForm.hcaptcha_site_key || ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({
                              ...current,
                              hcaptcha_site_key: event.target.value,
                            }))
                          }
                        />
                      </Field>
                      <label className="toggle">
                        <input
                          checked={Boolean(systemForm.registration_email_verify)}
                          type="checkbox"
                          onChange={(event) =>
                            setSystemForm((current) => ({
                              ...current,
                              registration_email_verify: event.target.checked,
                            }))
                          }
                        />
                        <span>注册必须验证邮箱</span>
                      </label>
                    </div>

                    <div className="form-subsection">
                      <h3>SMTP</h3>
                      <Field label="SMTP Host">
                        <input
                          value={systemForm.smtp_host || ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({ ...current, smtp_host: event.target.value }))
                          }
                        />
                      </Field>
                      <Field label="SMTP Port">
                        <input
                          type="number"
                          value={systemForm.smtp_port || ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({ ...current, smtp_port: event.target.value }))
                          }
                        />
                      </Field>
                      <Field label="SMTP From">
                        <input
                          value={systemForm.smtp_from || ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({ ...current, smtp_from: event.target.value }))
                          }
                        />
                      </Field>
                      <Field label="SMTP Username">
                        <input
                          value={systemForm.smtp_username || ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({
                              ...current,
                              smtp_username: event.target.value,
                            }))
                          }
                        />
                      </Field>
                      <Field label="SMTP Password">
                        <input
                          type="password"
                          value={systemForm.smtp_password || ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({
                              ...current,
                              smtp_password: event.target.value,
                            }))
                          }
                        />
                      </Field>
                      <Field label="Confirm Password">
                        <input
                          type="password"
                          value={systemForm.smtp_password_confirm || ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({
                              ...current,
                              smtp_password_confirm: event.target.value,
                            }))
                          }
                        />
                      </Field>
                      <label className="toggle">
                        <input
                          checked={Boolean(systemForm.smtp_secure)}
                          type="checkbox"
                          onChange={(event) =>
                            setSystemForm((current) => ({
                              ...current,
                              smtp_secure: event.target.checked,
                            }))
                          }
                        />
                        <span>启用安全连接</span>
                      </label>
                    </div>
                  </div>

                  <div className="security-grid">
                    {SECURITY_FIELDS.map(([key, label]) => (
                      <Field key={key} label={label}>
                        <input
                          min="1"
                          type="number"
                          value={systemForm[key] ?? ''}
                          onChange={(event) =>
                            setSystemForm((current) => ({ ...current, [key]: event.target.value }))
                          }
                        />
                      </Field>
                    ))}
                  </div>

                  <button type="submit">保存系统配置</button>
                </form>
              </Panel>
            </section>
          </div>
        )}

        {page === 'templates' && visiblePages.templates && (
          <div className="content-stack">
            <section className="panel-grid panel-grid-2">
              <Panel title="模板资产" description="先选中模板，再在右侧完成内容维护。">
                <div className="template-list">
                  {templates.map((template) => (
                    <button
                      key={template.name}
                      className={`template-chip ${selectedTemplate === template.name ? 'active' : ''}`}
                      onClick={() => handleTemplateSelect(template.name)}
                      type="button"
                    >
                      <strong>{template.name}</strong>
                      <span>{template.subject || '未设置主题'}</span>
                    </button>
                  ))}
                  {!templates.length && <EmptyState title="没有模板数据" body="请先确认后端模板接口是否返回资产。" />}
                </div>
              </Panel>

              <Panel title="模板摘要" description="保存前快速检查当前选中的模板内容。">
                {activeTemplate ? (
                  <KeyValueList
                    items={[
                      ['当前模板', activeTemplate.name || '-'],
                      ['邮件主题', activeTemplate.subject || '未设置'],
                      ['HTML 内容', activeTemplate.html ? `${activeTemplate.html.length} 字符` : '空'],
                      ['纯文本内容', activeTemplate.text ? `${activeTemplate.text.length} 字符` : '空'],
                    ]}
                  />
                ) : (
                  <EmptyState title="尚未选择模板" body="从左侧选中模板后即可查看摘要并开始编辑。" />
                )}
              </Panel>
            </section>

            <section className="panel-grid">
              <Panel title="模板编辑器" description="保留主题、HTML 与纯文本三个核心输入，避免引入无效演示字段。">
                <form className="stack" onSubmit={saveCurrentTemplate}>
                  <Field label="主题">
                    <input
                      value={templateForm.subject}
                      onChange={(event) =>
                        setTemplateForm((current) => ({ ...current, subject: event.target.value }))
                      }
                    />
                  </Field>
                  <Field label="HTML">
                    <textarea
                      rows="12"
                      value={templateForm.html}
                      onChange={(event) =>
                        setTemplateForm((current) => ({ ...current, html: event.target.value }))
                      }
                    />
                  </Field>
                  <Field label="纯文本">
                    <textarea
                      rows="7"
                      value={templateForm.text}
                      onChange={(event) =>
                        setTemplateForm((current) => ({ ...current, text: event.target.value }))
                      }
                    />
                  </Field>
                  <button disabled={!selectedTemplate} type="submit">
                    保存模板
                  </button>
                </form>
              </Panel>
            </section>
          </div>
        )}

        {page === 'oidc' && (
          <div className="content-stack">
            <section className="panel-grid panel-grid-2">
              <Panel
                title="协议发现"
                description="聚焦 issuer 与关键端点，不再直接暴露原始 JSON。"
                actions={
                  <button className="ghost" onClick={() => safely(loadDiscovery, '协议配置加载失败')} type="button">
                    刷新 Discovery
                  </button>
                }
              >
                {criticalEndpoints.length ? (
                  <KeyValueList items={criticalEndpoints} />
                ) : (
                  <EmptyState title="尚未加载 Discovery" body="刷新后可确认 issuer、授权端点与 JWKS 是否已正常发布。" />
                )}
              </Panel>

              <Panel
                title="客户端列表"
                description="点击任一客户端即可带入下方表单继续编辑。"
                actions={
                  <button className="ghost" onClick={() => safely(loadOidcClients, 'OIDC 客户端加载失败')} type="button">
                    刷新客户端
                  </button>
                }
              >
                <div className="client-list">
                  {oidcClients.map((client) => (
                    <button
                      key={client.client_id}
                      className="entity-card entity-card-button"
                      onClick={() => fillOidcFormFromClient(client, setOidcForm)}
                      type="button"
                    >
                      <div className="row-spread">
                        <strong>{client.client_id}</strong>
                        <span className={`status-dot ${client.is_active === false ? 'off' : 'on'}`}>
                          {client.is_active === false ? '停用' : '启用'}
                        </span>
                      </div>
                      <p>{(client.redirect_uris || []).join(', ') || '未配置 redirect URI'}</p>
                      <div className="badge-row">
                        {(client.scopes || []).slice(0, 5).map((scope) => (
                          <span key={scope} className="mini-badge">
                            {scope}
                          </span>
                        ))}
                      </div>
                    </button>
                  ))}
                  {!oidcClients.length && <EmptyState title="暂无客户端" body="创建后会立即出现在这里，并可再次选中进行维护。" />}
                </div>
              </Panel>
            </section>

            <section className="panel-grid panel-grid-2">
              <Panel title="客户端编辑" description="适用于新增，也适用于覆盖更新已有客户端。">
                <form className="stack" onSubmit={saveOidcClient}>
                  <Field label="Client ID">
                    <input
                      value={oidcForm.client_id}
                      onChange={(event) =>
                        setOidcForm((current) => ({ ...current, client_id: event.target.value }))
                      }
                      required
                    />
                  </Field>
                  <Field label="Redirect URIs">
                    <textarea
                      rows="5"
                      value={oidcForm.redirect_uris}
                      onChange={(event) =>
                        setOidcForm((current) => ({
                          ...current,
                          redirect_uris: event.target.value,
                        }))
                      }
                    />
                  </Field>
                  <Field label="Scopes">
                    <textarea
                      rows="4"
                      value={oidcForm.scopes}
                      onChange={(event) =>
                        setOidcForm((current) => ({ ...current, scopes: event.target.value }))
                      }
                    />
                  </Field>
                  <Field label="Grant Types">
                    <textarea
                      rows="4"
                      value={oidcForm.grant_types}
                      onChange={(event) =>
                        setOidcForm((current) => ({ ...current, grant_types: event.target.value }))
                      }
                    />
                  </Field>
                  <Field label="Client Secret">
                    <input
                      type="password"
                      value={oidcForm.client_secret}
                      onChange={(event) =>
                        setOidcForm((current) => ({ ...current, client_secret: event.target.value }))
                      }
                    />
                  </Field>
                  <label className="toggle">
                    <input
                      checked={oidcForm.is_confidential}
                      type="checkbox"
                      onChange={(event) =>
                        setOidcForm((current) => ({
                          ...current,
                          is_confidential: event.target.checked,
                        }))
                      }
                    />
                    <span>Confidential Client</span>
                  </label>
                  <label className="toggle">
                    <input
                      checked={oidcForm.is_active}
                      type="checkbox"
                      onChange={(event) =>
                        setOidcForm((current) => ({ ...current, is_active: event.target.checked }))
                      }
                    />
                    <span>启用客户端</span>
                  </label>
                  <button type="submit">保存 OIDC 客户端</button>
                </form>
              </Panel>

              <Panel title="当前表单摘要" description="用于提交前核对关键字段是否正确。">
                <KeyValueList
                  items={[
                    ['Client ID', oidcForm.client_id || '未填写'],
                    ['Redirect URI 数量', `${normalizeLines(oidcForm.redirect_uris).length} 条`],
                    ['Scope 数量', `${normalizeLines(oidcForm.scopes).length} 条`],
                    ['Grant Type 数量', `${normalizeLines(oidcForm.grant_types).length} 条`],
                    ['客户端类型', oidcForm.is_confidential ? 'Confidential' : 'Public'],
                    ['启用状态', oidcForm.is_active ? '启用' : '停用'],
                  ]}
                />
              </Panel>
            </section>
          </div>
        )}

        {page === 'users' && visiblePages.users && (
          <div className="content-stack">
            <section className="panel-grid panel-grid-2">
              <Panel title="用户池摘要" description="先掌握规模与角色分布，再进入列表核对。">
                <div className="insight-list">
                  <InfoTile title="用户总数" value={`${users.length}`} tone="neutral" />
                  <InfoTile title="角色种类" value={`${roleSummary.length}`} tone="neutral" />
                  <InfoTile title="管理员" value={`${roleSummary.find(([role]) => role === 'admin')?.[1] || 0}`} tone="neutral" />
                  <InfoTile title="普通账号" value={`${users.filter((user) => !(user.roles || []).includes('admin')).length}`} tone="neutral" />
                </div>
              </Panel>

              <Panel title="角色分布" description="用于快速判断权限是否出现异常扩散。">
                <div className="role-summary-list">
                  {roleSummary.map(([role, count]) => (
                    <article key={role} className="summary-row">
                      <strong>{role}</strong>
                      <span>{count} 人</span>
                    </article>
                  ))}
                  {!roleSummary.length && <EmptyState title="暂无角色数据" body="刷新用户列表后，这里会显示实际权限分布。" />}
                </div>
              </Panel>
            </section>

            <Panel
              title="用户列表"
              description="表格只保留管理动作最常核对的字段。"
              actions={
                <button className="ghost" onClick={() => safely(loadUsers, '用户数据加载失败')} type="button">
                  刷新用户
                </button>
              }
            >
              {users.length ? (
                <div className="table-wrap">
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>邮箱</th>
                        <th>昵称</th>
                        <th>角色</th>
                        <th>ID</th>
                      </tr>
                    </thead>
                    <tbody>
                      {users.map((user, index) => (
                        <tr key={user.id || `${user.email}-${index}`}>
                          <td>{user.email || '-'}</td>
                          <td>{user.nickname || '-'}</td>
                          <td>
                            <div className="badge-row">
                              {(user.roles || []).map((role) => (
                                <span key={role} className="mini-badge">
                                  {role}
                                </span>
                              ))}
                            </div>
                          </td>
                          <td className="mono-cell">{user.id || '-'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <EmptyState title="还没有用户数据" body="点击刷新后，这里会显示接口返回的用户列表。" />
              )}
            </Panel>
          </div>
        )}

        {page === 'audits' && visiblePages.audits && (
          <div className="content-stack">
            <section className="panel-grid panel-grid-2">
              <Panel title="审计摘要" description="先看最近事件规模与时间，再决定是否继续排查。">
                <div className="insight-list">
                  <InfoTile title="记录总数" value={`${audits.length}`} tone="neutral" />
                  <InfoTile title="最新事件" value={audits[0] ? formatAnyDate(audits[0].created_at || audits[0].timestamp || audits[0].time) : '暂无'} tone="neutral" />
                  <InfoTile title="最近操作者" value={audits[0]?.email || audits[0]?.actor || audits[0]?.user_email || '暂无'} tone="neutral" />
                  <InfoTile title="最近动作" value={audits[0]?.action || audits[0]?.type || '暂无'} tone="neutral" />
                </div>
              </Panel>

              <Panel title="审计说明" description="用于快速理解这组数据的阅读方式。">
                <div className="priority-list">
                  <article className="priority-card neutral">
                    <strong>时间优先</strong>
                    <p>审计记录默认按最近事件阅读，先判断是否与刚发生的管理动作一致。</p>
                  </article>
                  <article className="priority-card neutral">
                    <strong>操作者与来源 IP 结合判断</strong>
                    <p>若动作与账号身份不一致，应继续检查会话来源、权限变更和令牌签发链路。</p>
                  </article>
                </div>
              </Panel>
            </section>

            <Panel
              title="审计时间线"
              description="保留事件关键信息，去掉直接堆叠原始对象的调试做法。"
              actions={
                <button className="ghost" onClick={() => safely(loadAudits, '审计数据加载失败')} type="button">
                  刷新审计
                </button>
              }
            >
              <div className="timeline">
                {audits.map((entry, index) => (
                  <article key={entry.id || `${entry.action || 'audit'}-${index}`} className="timeline-item">
                    <div className="timeline-dot" />
                    <div className="timeline-body">
                      <div className="row-spread">
                        <strong>{entry.action || entry.type || '未知动作'}</strong>
                        <span>{formatAnyDate(entry.created_at || entry.timestamp || entry.time)}</span>
                      </div>
                      <div className="audit-detail-grid">
                        {describeAudit(entry).map(([label, value]) => (
                          <div key={`${entry.id || index}-${label}`} className="audit-detail-item">
                            <span>{label}</span>
                            <strong>{value || '-'}</strong>
                          </div>
                        ))}
                      </div>
                    </div>
                  </article>
                ))}
                {!audits.length && <EmptyState title="暂无审计记录" body="点击刷新后，这里会展示后端返回的审计事件。" />}
              </div>
            </Panel>
          </div>
        )}
      </main>
    </section>
  );
}
