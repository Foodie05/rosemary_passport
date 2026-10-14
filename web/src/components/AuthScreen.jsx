import { FormaButton, FormaInput } from './Forma';
import { Field, InfoPill } from './ui';

export function AuthScreen({
  authMode,
  loginStep,
  status,
  session,
  publicConfig,
  loading,
  loginForm,
  registerForm,
  captchaRef,
  setAuthMode,
  setLoginStep,
  setLoginForm,
  setRegisterForm,
  prepareLogin,
  completeLogin,
  submitRegister,
  submitRegisterCode,
}) {
  return (
    <section className="auth-shell">
      <div className="auth-copy">
        <p className="eyebrow">Rosemary Epass</p>
        <h1>身份系统后台，换一种更轻盈的打开方式。</h1>
        <p className="lede">
          登录、注册、配置与 OIDC 接入仍然保留，但界面重新组织得更清晰，更适合日常管理。
        </p>
        <div className="auth-points">
          <InfoPill label="邮件验证码" value="内建" />
          <InfoPill label="后台角色" value={session.user?.roles?.join(', ') || '待登录'} />
          <InfoPill label="阿里云验证码" value={publicConfig?.captcha?.scene_id ? '已启用' : '可选'} />
        </div>
      </div>

      <section className="auth-card">
        <div className="auth-meta">
          <p className="eyebrow">Control Access</p>
          <p className="status">{status}</p>
        </div>
        {authMode === 'login' ? (
          <form className="stack" onSubmit={loginStep === 'credentials' ? prepareLogin : completeLogin}>
            <div className="section-heading">
              <h2>{loginStep === 'credentials' ? '欢迎回来' : '完成邮箱验证'}</h2>
              <p>保持现有登录逻辑不变，只把体验做得更顺手。</p>
            </div>
            {loginStep === 'credentials' ? (
              <>
                <Field label="邮箱">
                  <FormaInput
                    type="email"
                    value={loginForm.email}
                    onChange={(event) =>
                      setLoginForm((current) => ({ ...current, email: event.target.value }))
                    }
                    required
                  />
                </Field>
                <Field label="密码">
                  <FormaInput
                    type="password"
                    value={loginForm.password}
                    onChange={(event) =>
                      setLoginForm((current) => ({ ...current, password: event.target.value }))
                    }
                    required
                  />
                </Field>
                <FormaButton disabled={loading} type="submit">
                  {loading ? '校验中...' : '下一步'}
                </FormaButton>
              </>
            ) : (
              <>
                <Field label="邮箱验证码">
                  <FormaInput
                    value={loginForm.email_code}
                    onChange={(event) =>
                      setLoginForm((current) => ({ ...current, email_code: event.target.value }))
                    }
                    placeholder="请输入邮箱中的验证码"
                    required
                  />
                </Field>
                <div className="button-row">
                  <FormaButton className="ghost" type="button" onClick={() => setLoginStep('credentials')}>
                    返回上一步
                  </FormaButton>
                  <FormaButton disabled={loading} type="submit">
                    {loading ? '登录中...' : '完成登录'}
                  </FormaButton>
                </div>
              </>
            )}
            <p className="switch-copy">
              没有账号？
              <FormaButton className="text-link" type="button" onClick={() => setAuthMode('register')}>
                立即注册
              </FormaButton>
            </p>
          </form>
        ) : (
          <form className="stack" onSubmit={submitRegister}>
            <div className="section-heading">
              <h2>创建后台账号</h2>
              <p>注册流程、验证码与风控逻辑全部沿用当前接口。</p>
            </div>
            <Field label="邮箱">
              <FormaInput
                type="email"
                value={registerForm.email}
                onChange={(event) =>
                  setRegisterForm((current) => ({ ...current, email: event.target.value }))
                }
                required
              />
            </Field>
            <div className="captcha">
              <div ref={captchaRef} />
            </div>
            <FormaButton className="ghost" type="button" onClick={submitRegisterCode}>
              发送验证码
            </FormaButton>
            <Field label="邮箱验证码">
              <FormaInput
                value={registerForm.email_code}
                onChange={(event) =>
                  setRegisterForm((current) => ({ ...current, email_code: event.target.value }))
                }
                required
              />
            </Field>
            <Field label="昵称">
              <FormaInput
                value={registerForm.nickname}
                onChange={(event) =>
                  setRegisterForm((current) => ({ ...current, nickname: event.target.value }))
                }
                required
              />
            </Field>
            <Field label="密码">
              <FormaInput
                type="password"
                value={registerForm.password}
                onChange={(event) =>
                  setRegisterForm((current) => ({ ...current, password: event.target.value }))
                }
                required
              />
            </Field>
            <FormaButton disabled={loading} type="submit">
              {loading ? '注册中...' : '注册并登录'}
            </FormaButton>
            <p className="switch-copy">
              已有账号？
              <FormaButton className="text-link" type="button" onClick={() => setAuthMode('login')}>
                去登录
              </FormaButton>
            </p>
          </form>
        )}
      </section>
    </section>
  );
}
