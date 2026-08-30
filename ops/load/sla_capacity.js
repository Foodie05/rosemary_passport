import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';

const baseUrl = (__ENV.BASE_URL || 'http://127.0.0.1:8091').replace(/\/$/, '');
const browserOrigin = __ENV.BROWSER_ORIGIN || baseUrl;
const refreshCookieName = baseUrl.startsWith('https://')
  ? '__Host-rosm_refresh_token'
  : 'rosm_refresh_token';
const sessionFile = __ENV.SESSION_FILE || './sessions.json';
const sustainedDuration = __ENV.SUSTAINED_DURATION || '30m';
const burstDuration = __ENV.BURST_DURATION || '5m';
const burstStart = __ENV.BURST_START || '30m';
const sessionDuration = __ENV.SESSION_DURATION || '5m';
const sessionStart = __ENV.SESSION_START || '35m';
const sessionRamp = __ENV.SESSION_RAMP || '30s';
const sustainedRate = Number(__ENV.SUSTAINED_RATE || 50);
const burstRate = Number(__ENV.BURST_RATE || 100);
const concurrentSessions = Number(__ENV.CONCURRENT_SESSIONS || 500);
const sustainedMaxVUs = Number(__ENV.SUSTAINED_MAX_VUS || 500);
const burstMaxVUs = Number(__ENV.BURST_MAX_VUS || 500);
const refreshAfterSeconds = Number(__ENV.REFRESH_AFTER_SECONDS || 720);
const scenarioSessionPoolSize = Math.max(
  sustainedMaxVUs,
  burstMaxVUs,
  concurrentSessions,
);
const requiredSessions = scenarioSessionPoolSize * 3;
const sessions = new SharedArray('first-party sessions', () => {
  const parsed = JSON.parse(open(sessionFile));
  if (!Array.isArray(parsed)) {
    throw new Error('SESSION_FILE must contain a JSON array');
  }
  return parsed;
});
let initialized = false;
let activeScenario = '';
let refreshAt = 0;
let accessToken = '';
let refreshToken = '';

export const options = {
  scenarios: {
    sustained_50_rps: {
      executor: 'constant-arrival-rate',
      rate: sustainedRate,
      timeUnit: '1s',
      duration: sustainedDuration,
      preAllocatedVUs: Math.min(100, sustainedMaxVUs),
      maxVUs: sustainedMaxVUs,
      gracefulStop: '0s',
    },
    burst_100_rps: {
      executor: 'constant-arrival-rate',
      rate: burstRate,
      timeUnit: '1s',
      duration: burstDuration,
      startTime: burstStart,
      preAllocatedVUs: Math.min(200, burstMaxVUs),
      maxVUs: burstMaxVUs,
      gracefulStop: '0s',
    },
    concurrent_sessions: {
      executor: 'ramping-vus',
      exec: 'sessionActivity',
      startVUs: 0,
      stages: [
        { duration: sessionRamp, target: concurrentSessions },
        { duration: sessionDuration, target: concurrentSessions },
      ],
      startTime: sessionStart,
      gracefulStop: '0s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.001'],
    http_req_duration: ['p(95)<300', 'p(99)<800'],
  },
};

export function setup() {
  if (sessions.length < requiredSessions) {
    throw new Error(
      `SESSION_FILE must contain at least ${requiredSessions} distinct sessions`,
    );
  }
  const refreshTokens = new Set();
  for (let index = 0; index < requiredSessions; index += 1) {
    const session = sessions[index];
    if (
      typeof session?.access_token !== 'string' ||
      typeof session?.refresh_token !== 'string' ||
      session.access_token.length === 0 ||
      session.refresh_token.length === 0
    ) {
      throw new Error(`session ${index} is missing access_token or refresh_token`);
    }
    refreshTokens.add(session.refresh_token);
  }
  if (refreshTokens.size !== requiredSessions) {
    throw new Error('SESSION_FILE must not reuse refresh tokens between VUs');
  }
}

function authenticatedRequest() {
  const scenarioOffsets = {
    sustained_50_rps: 0,
    burst_100_rps: scenarioSessionPoolSize,
    concurrent_sessions: scenarioSessionPoolSize * 2,
  };
  const scenarioName = exec.scenario.name;
  const sessionIndex = scenarioOffsets[scenarioName] + __VU - 1;
  const session = sessions[sessionIndex];
  if (!session) {
    throw new Error(`no isolated session allocated for VU ${__VU}`);
  }
  const sourceIp = `198.18.${Math.floor(sessionIndex / 250)}.${(sessionIndex % 250) + 1}`;
  const jar = http.cookieJar();
  if (!initialized || activeScenario !== scenarioName) {
    activeScenario = scenarioName;
    accessToken = session.access_token;
    refreshToken = session.refresh_token;
    jar.set(baseUrl, 'rosm_access_token', session.access_token, { path: '/' });
    jar.set(baseUrl, 'rosm_refresh_token', session.refresh_token, { path: '/' });
    // Rotate before the first profile request. This keeps delayed scenarios
    // independent of the 15-minute access-token lifetime and proves the
    // cookie refresh path is healthy before their measurements continue.
    refreshAt = 0;
    initialized = true;
  }
  if (Date.now() >= refreshAt) {
    const refreshed = http.post(`${baseUrl}/api/v1/auth/refresh`, '{}', {
      headers: {
        'Content-Type': 'application/json',
        Origin: browserOrigin,
        'X-Forwarded-For': sourceIp,
        Cookie: `${refreshCookieName}=${refreshToken}`,
      },
      tags: { name: 'session_refresh' },
    });
    check(refreshed, { 'session refresh succeeds': (r) => r.status === 200 });
    if (refreshed.status !== 200) {
      console.warn(JSON.stringify({
        event: 'capacity.refresh_failed',
        vu: __VU,
        status: refreshed.status,
        cookie_names: Object.keys(jar.cookiesForURL(baseUrl)),
        body_preview: refreshed.body ? refreshed.body.slice(0, 160) : null,
      }));
    }
    const accessCookies = refreshed.cookies.rosm_access_token || [];
    const refreshCookies = refreshed.cookies[refreshCookieName] || [];
    if (accessCookies.length > 0) {
      accessToken = accessCookies[0].value;
    }
    if (refreshCookies.length > 0) {
      refreshToken = refreshCookies[0].value;
    }
    refreshAt = Date.now() + refreshAfterSeconds * 1000;
  }
  const response = http.get(`${baseUrl}/api/v1/me`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'X-Forwarded-For': sourceIp,
    },
    tags: { name: 'authenticated_profile' },
  });
  if (response.status !== 200) {
    let errorCode = null;
    if (response.body) {
      try {
        const payload = response.json();
        errorCode = payload.error || payload.code || null;
      } catch (_) {
        // Non-JSON proxy/network responses are summarized by status and body.
      }
    }
    console.warn(JSON.stringify({
      event: 'capacity.unexpected_status',
      vu: __VU,
      session_index: sessionIndex,
      status: response.status,
      error_code: errorCode,
      body_preview: response.body ? response.body.slice(0, 160) : null,
    }));
  }
  check(response, { 'authenticated endpoint is healthy': (r) => r.status === 200 });
}

export default function () {
  authenticatedRequest();
}

export function sessionActivity() {
  authenticatedRequest();
  // Five hundred active sessions at one request per five seconds produce an
  // aggregate 100 RPS, exercising the concurrency target without redefining
  // it as an unintended 500 RPS throughput target.
  sleep(4 + Math.random() * 2);
}
