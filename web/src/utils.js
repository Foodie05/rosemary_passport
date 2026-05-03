export function getInitial(value = '') {
  return value.trim().charAt(0).toUpperCase() || 'R';
}

export function cleanDisplayName(value = '', fallback = '-') {
  const normalized = `${value}`
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, ' ')
    .replace(/[\\/]{3,}/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  return normalized || fallback;
}

export function formatAnyDate(value) {
  if (!value) {
    return '未知时间';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return `${value}`;
  }
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}
