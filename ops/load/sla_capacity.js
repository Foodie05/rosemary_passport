import http from 'k6/http';
import { check } from 'k6';

const baseUrl = (__ENV.BASE_URL || 'http://127.0.0.1:8091').replace(/\/$/, '');
const accessToken = __ENV.ACCESS_TOKEN || '';

export const options = {
  scenarios: {
    sustained_50_rps: {
      executor: 'constant-arrival-rate',
      rate: 50,
      timeUnit: '1s',
      duration: '30m',
      preAllocatedVUs: 100,
      maxVUs: 500,
    },
    burst_100_rps: {
      executor: 'constant-arrival-rate',
      rate: 100,
      timeUnit: '1s',
      duration: '5m',
      startTime: '30m',
      preAllocatedVUs: 200,
      maxVUs: 500,
    },
    concurrent_sessions: {
      executor: 'constant-vus',
      vus: 500,
      duration: '5m',
      startTime: '35m',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.001'],
    http_req_duration: ['p(95)<300', 'p(99)<800'],
  },
};

export function setup() {
  if (!accessToken) {
    throw new Error('ACCESS_TOKEN is required for the 500-session acceptance run');
  }
}

export default function () {
  const response = http.get(`${baseUrl}/api/v1/me`, {
    headers: { Authorization: `Bearer ${accessToken}` },
    tags: { name: 'authenticated_profile' },
  });
  check(response, { 'authenticated endpoint is healthy': (r) => r.status === 200 });
}
