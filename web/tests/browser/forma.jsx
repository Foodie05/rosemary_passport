import React, {useState} from 'react';
import {createRoot} from 'react-dom/client';
import {MemoryRouter, Routes, Route} from 'react-router-dom';
import {ThemeProvider} from '../../src/theme';
import {MotionPreferences} from '../../src/design/MotionPreferences';
import {RosemaryDialogProvider} from '../../src/components/ui';
import {AdminLayout, UserLayout} from '../../src/components/Layouts';
import {UserAccountPage} from '../../src/pages/UserPages';
import {AdminDashboard, AdminUsers, AdminServiceConfig, AdminSecurityPolicy, AdminOIDCConfig, AdminStatusManagement, AdminLegalDocuments, AdminOidcDocsPage, AdminFlutterSdkDocsPage} from '../../src/pages/AdminPages';
import {LegalDocumentPage, BannedPage} from '../../src/pages/LegalPages';
import {RegisterPage} from '../../src/pages/AuthPages';
import '../../src/styles.css';
const noop = async () => {};
if (new URLSearchParams(location.search).get('scale') === '2') document.documentElement.style.zoom = '2';
const safely = async task => task();
const session = {user:{id:'epass-preview',nickname:'Rosemary',email:'hello@example.com',roles:['user'],phone_number:''},security:{must_bind_email:false,has_password:true,has_authenticator:false,has_passkey:false,step_up_methods:['password','email_code','phone_code','authenticator','passkey']}};
const rows=Array.from({length:7},(_,i)=>({date:`2026-10-0${i+1}`,total_users:420+i*15,new_users:12+i*3,logins:50+i*8,authorizations:32+i*5,email_codes:18+i*4,sms_codes:6+i*3}));
const dashboard={summary:{total_users:510,banned_users:2,active_third_party_oidc_clients:6,active_oidc_clients:9},user_growth:rows,authentication_activity:rows,verification_activity:rows};
const view = new URLSearchParams(location.search).get('view') || 'account';
function Preview(){
 const [registerForm,setRegisterForm]=useState({nickname:'',email:'',phone_number:'',email_code:'',phone_code:'',password:''});
 const [registerMethod,setRegisterMethod]=useState('email');
 const [legalAccepted,setLegalAccepted]=useState(false);
 const [systemForm,setSystemForm]=useState({registration_email_verify:true});
 const [oidcForm,setOidcForm]=useState({client_id:'',display_name:'',redirect_uris:'',scopes:['openid','profile'],is_official:false,is_active:true});
 const account = <UserAccountPage session={session} mustBindEmail={false} updateNicknameSilently={noop} listWebAuthnCredentials={async()=>({credentials:[],max_count:5})} sendStepUpCode={noop} />;
 return <MotionPreferences><ThemeProvider><RosemaryDialogProvider><MemoryRouter initialEntries={[view==='account'?'/account':`/admin/${view}`]}><Routes>
 <Route path="/admin/register" element={<RegisterPage registerForm={registerForm} setRegisterForm={setRegisterForm} registerMethod={registerMethod} setRegisterMethod={setRegisterMethod} loading={false} registerCodeSending={false} registerCodeCooldownRemaining={0} submitRegister={e=>e.preventDefault()} submitRegisterCode={noop} captchaConfigured={false} legalAccepted={legalAccepted} setLegalAccepted={setLegalAccepted} legalDocuments={{terms:{version:1},privacy:{version:1}}} />}/>
 <Route path="/admin/docs" element={<AdminOidcDocsPage discovery={{issuer:'https://auth.example.com'}} oidcSettings={{}}/>}/>
 <Route path="/admin/flutter" element={<AdminFlutterSdkDocsPage discovery={{issuer:'https://auth.example.com'}} oidcSettings={{}}/>}/>
 <Route path="/admin/terms" element={<LegalDocumentPage document={{title:'Rosemary Epass 使用条款',version:1,content:'示例条款正文，仅用于页面外观验证。\n\n账户与认证\n使用 Rosemary Epass 登录接入应用。'}} loading={false}/>}/>
 <Route path="/admin/banned" element={<BannedPage account="example@example.com"/>}/>
 <Route path="/account" element={<UserLayout session={session} logout={noop}/>}><Route index element={account}/></Route>
 <Route path="/admin" element={<AdminLayout session={{...session,user:{...session.user,roles:['admin']}}} logout={noop}/>}>
 <Route path="status" element={<AdminStatusManagement cooldowns={[]} pagination={{page:1,total_pages:1,total:0}} loadCooldowns={noop} resetCooldown={noop} safely={safely}/>}/>
 <Route path="legal" element={<AdminLegalDocuments documents={[]} loadDocuments={noop} saveDraft={noop} publishDocument={noop} safely={safely}/>}/>
 <Route path="dashboard" element={<AdminDashboard data={dashboard} loadDashboard={noop} safely={safely}/>}/>
 <Route path="users" element={<AdminUsers users={[session.user,{id:'epass-02',email:'member@example.com',nickname:'示例成员',roles:['user'],status:'active'}]} pagination={{page:1,total_pages:1,total:2}} loadUsers={noop} loadUser={async()=>session.user} safely={safely}/>}/>
 <Route path="account" element={account}/>
 <Route path="service" element={<AdminServiceConfig systemForm={systemForm} setSystemForm={setSystemForm} saveServiceConfig={e=>e.preventDefault()}/>}/>
 <Route path="security" element={<AdminSecurityPolicy systemForm={systemForm} setSystemForm={setSystemForm} saveSecurityPolicy={e=>e.preventDefault()} />}/>
 <Route path="oidc" element={<AdminOIDCConfig discovery={{}} oidcClients={[{client_id:'com.example.reader',display_name:'示例阅读应用',is_active:true,redirect_uris:['https://example.com/auth/callback']}]} oidcForm={oidcForm} setOidcForm={setOidcForm} loadDiscovery={noop} loadOidcClients={noop} safely={safely}/>}/>
 </Route></Routes></MemoryRouter></RosemaryDialogProvider></ThemeProvider></MotionPreferences>;
}
createRoot(document.getElementById('root')).render(<Preview/>);
