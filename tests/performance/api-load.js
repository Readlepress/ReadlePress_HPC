import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api/v1';
const TEST_EMAIL = __ENV.TEST_EMAIL || 'teacher@school.example.com';
const TEST_PASSWORD = __ENV.TEST_PASSWORD || 'TeacherPass123!';

const loginDuration = new Trend('login_duration', true);
const studentListDuration = new Trend('student_list_duration', true);
const masterySummaryDuration = new Trend('mastery_summary_duration', true);
const competencyListDuration = new Trend('competency_list_duration', true);
const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    login_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 100 },
        { duration: '1m', target: 1000 },
        { duration: '30s', target: 1000 },
        { duration: '30s', target: 0 },
      ],
      exec: 'loginTest',
    },
    api_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 50 },
        { duration: '2m', target: 200 },
        { duration: '30s', target: 0 },
      ],
      exec: 'apiTests',
      startTime: '10s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<800', 'p(99)<2000'],
    http_req_failed: ['rate<0.01'],
    login_duration: ['p(95)<800'],
    student_list_duration: ['p(95)<800'],
    mastery_summary_duration: ['p(95)<800'],
    competency_list_duration: ['p(95)<800'],
    errors: ['rate<0.01'],
  },
};

function getAuthToken() {
  const loginRes = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  if (loginRes.status !== 200) {
    errorRate.add(1);
    return null;
  }

  const body = JSON.parse(loginRes.body);
  return body.token;
}

export function loginTest() {
  const start = Date.now();
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  loginDuration.add(Date.now() - start);

  check(res, {
    'login status is 200': (r) => r.status === 200,
    'login returns token': (r) => {
      try {
        return JSON.parse(r.body).token !== undefined;
      } catch {
        return false;
      }
    },
  }) || errorRate.add(1);

  sleep(0.5);
}

export function apiTests() {
  const token = getAuthToken();
  if (!token) return;

  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  group('Student List', () => {
    const start = Date.now();
    const res = http.get(`${BASE_URL}/students`, { headers: authHeaders });
    studentListDuration.add(Date.now() - start);

    check(res, {
      'students status is 200': (r) => r.status === 200,
      'students returns array': (r) => {
        try {
          return Array.isArray(JSON.parse(r.body).students);
        } catch {
          return false;
        }
      },
    }) || errorRate.add(1);
  });

  sleep(0.3);

  group('Mastery Summary', () => {
    const studentId = '00000000-0000-0000-0000-000000000001';
    const start = Date.now();
    const res = http.get(`${BASE_URL}/students/${studentId}/mastery-summary`, {
      headers: authHeaders,
    });
    masterySummaryDuration.add(Date.now() - start);

    check(res, {
      'mastery status is 200': (r) => r.status === 200,
      'mastery returns aggregates': (r) => {
        try {
          return Array.isArray(JSON.parse(r.body).aggregates);
        } catch {
          return false;
        }
      },
    }) || errorRate.add(1);
  });

  sleep(0.3);

  group('Competency List', () => {
    const start = Date.now();
    const res = http.get(`${BASE_URL}/competencies`, { headers: authHeaders });
    competencyListDuration.add(Date.now() - start);

    check(res, {
      'competencies status is 200': (r) => r.status === 200,
    }) || errorRate.add(1);
  });

  sleep(1);
}

export default function () {
  apiTests();
}
