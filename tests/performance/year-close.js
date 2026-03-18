import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api/v1';
const PRINCIPAL_EMAIL = __ENV.PRINCIPAL_EMAIL || 'principal@school.example.com';
const PRINCIPAL_PASSWORD = __ENV.PRINCIPAL_PASSWORD || 'PrincipalPass123!';

const completenessCheckDuration = new Trend('completeness_check_duration', true);
const aggregationDuration = new Trend('aggregation_per_student_duration', true);
const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    year_close_completeness: {
      executor: 'per-vu-iterations',
      vus: 5,
      iterations: 1,
      exec: 'completenessCheck',
      maxDuration: '5m',
    },
    year_close_aggregation: {
      executor: 'per-vu-iterations',
      vus: 10,
      iterations: 1,
      exec: 'aggregationJob',
      startTime: '10s',
      maxDuration: '5m',
    },
  },
  thresholds: {
    completeness_check_duration: ['p(95)<30000'],
    aggregation_per_student_duration: ['p(95)<5000'],
    errors: ['rate<0.05'],
  },
};

function getAuthToken() {
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email: PRINCIPAL_EMAIL, password: PRINCIPAL_PASSWORD }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  if (res.status !== 200) {
    errorRate.add(1);
    return null;
  }

  return JSON.parse(res.body).token;
}

export function completenessCheck() {
  const token = getAuthToken();
  if (!token) return;

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // List academic years to find one in REVIEW status
  const yearsRes = http.get(`${BASE_URL}/academic-years`, { headers });
  if (yearsRes.status !== 200) {
    errorRate.add(1);
    return;
  }

  const years = JSON.parse(yearsRes.body).academicYears || [];
  const reviewYear = years.find((y) => y.status === 'REVIEW');

  if (!reviewYear) {
    console.log('No academic year in REVIEW status found, skipping');
    return;
  }

  const start = Date.now();
  const closeRes = http.post(`${BASE_URL}/academic-years/${reviewYear.id}/close`, null, {
    headers,
    timeout: '60s',
  });
  const duration = Date.now() - start;
  completenessCheckDuration.add(duration);

  check(closeRes, {
    'year close returns valid response': (r) => r.status === 200 || r.status === 409,
    'completeness check under 30s': () => duration < 30000,
  }) || errorRate.add(1);

  console.log(`Year close completeness check took ${duration}ms`);
}

export function aggregationJob() {
  const token = getAuthToken();
  if (!token) return;

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // Fetch students and verify mastery for each
  const studentsRes = http.get(`${BASE_URL}/students`, { headers });
  if (studentsRes.status !== 200) {
    errorRate.add(1);
    return;
  }

  const students = JSON.parse(studentsRes.body).students || [];

  for (const student of students.slice(0, 20)) {
    const start = Date.now();
    const summaryRes = http.get(
      `${BASE_URL}/students/${student.id}/mastery-summary`,
      { headers }
    );
    const duration = Date.now() - start;
    aggregationDuration.add(duration);

    check(summaryRes, {
      'mastery summary status 200': (r) => r.status === 200,
      'aggregation per student under 5s': () => duration < 5000,
    }) || errorRate.add(1);
  }

  sleep(1);
}

export default function () {
  completenessCheck();
}
