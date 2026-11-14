import {RosemaryCheckbox} from './ui';
const labels={user:'普通用户',admin:'管理员'};
export function RolePicker({roles,onChange,supportedRoles,disabled=false}) {
  return <fieldset className="min-w-0 space-y-2"><legend className="mb-2 text-sm font-medium text-ink">角色</legend>
    <div className="flex flex-wrap gap-x-6 gap-y-2">{supportedRoles.map(role=><RosemaryCheckbox key={role} checked={roles.includes(role)} disabled={disabled} onCheckedChange={checked=>onChange(checked?[...new Set([...roles,role])]:roles.filter(value=>value!==role))}>{labels[role]||role}（{role}）</RosemaryCheckbox>)}</div>
    <p className="text-sm text-muted">{supportedRoles.length?'至少保留一个角色。':'正在读取受支持角色，暂时不能应用更改。'}</p>
  </fieldset>;
}
