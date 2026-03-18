import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api/v1';
const TEST_EMAIL = __ENV.TEST_EMAIL || 'teacher@school.example.com';
const TEST_PASSWORD = __ENV.TEST_PASSWORD || 'TeacherPass123!';

const syncDuration = new Trend('sync_batch_duration', true);
const syncedObservations = new Counter('synced_observations');
const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    simultaneous_teachers: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '15s', target: 10 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 50 },
        { duration: '15s', target: 0 },
      ],
      exec: 'syncBatch',
    },
    burst_sync: {
      executor: 'per-vu-iterations',
      vus: 10,
      iterations: 1,
      exec: 'largeSyncBatch',
      startTime: '30s',
      maxDuration: '5m',
    },
  },
  thresholds: {
    sync_batch_duration: ['p(95)<30000'],
    errors: ['rate<0.05'],
  },
};

function getAuthToken() {
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  if (res.status !== 200) {
    errorRate.add(1);
    return null;
  }

  return JSON.parse(res.body).token;
}

function generateDrafts(count) {
  const drafts = [];
  const now = new Date();

  for (let i = 0; i < count; i++) {
    const observedAt = new Date(now.getTime() - Math.random() * 7 * 24 * 60 * 60 * 1000);
    drafts.push({
      localId: `sync-${__VU}-${__ITER}-${i}-${Date.now()}`,
      studentId: '00000000-0000-0000-0000-000000000001',
      competencyId: '00000000-0000-0000-0000-000000000300',
      observedAt: observedAt.toISOString(),
      recordedAt: now.toISOString(),
      timestampSource: 'DEVICE',
      timestampConfidence: 'HIGH',
      numericValue: Math.round(Math.random() * 100) / 100,
      observationNote: `Performance test observation VU:${__VU} iter:${__ITER} draft:${i}`,
      sourceType: 'DIRECT_OBSERVATION',
      deviceId: `perf-device-${__VU}`,
    });
  }

  return drafts;
}

export function syncBatch() {
  const token = getAuthToken();
  if (!token) return;

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  const batchSize = 10;
  const drafts = generateDrafts(batchSize);

  const start = Date.now();
  const res = http.post(
    `${BASE_URL}/capture/sync`,
    JSON.stringify({
      teacherId: '00000000-0000-0000-0000-000000000050',
      drafts,
    }),
    { headers, timeout: '30s' }
  );
  const duration = Date.now() - start;
  syncDuration.add(duration);

  const success = check(res, {
    'sync status is 200': (r) => r.status === 200,
    'sync returns results': (r) => {
      try {
        return JSON.parse(r.body).results !== undefined;
      } catch {
        return false;
      }
    },
    'sync batch under 30s': () => duration < 30000,
  });

  if (success) {
    syncedObservations.add(batchSize);
  } else {
    errorRate.add(1);
  }

  sleep(1);
}

export function largeSyncBatch() {
  const token = getAuthToken();
  if (!token) return;

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // Sync 100 observations in a single batch (target: < 30s)
  const drafts = generateDrafts(100);

  const start = Date.now();
  const res = http.post(
    `${BASE_URL}/capture/sync`,
    JSON.stringify({
      teacherId: '00000000-0000-0000-0000-000000000050',
      drafts,
    }),
    { headers, timeout: '60s' }
  );
  const duration = Date.now() - start;
  syncDuration.add(duration);

  check(res, {
    'large sync status is 200': (r) => r.status === 200,
    '100 observations sync under 30s': () => duration < 30000,
    'all 100 observations have results': (r) => {
      try {
        return JSON.parse(r.body).results.length === 100;
      } catch {
        return false;
      }
    },
  }) || errorRate.add(1);

  if (res.status === 200) {
    syncedObservations.add(100);
  }

  console.log(`Large sync (100 observations) took ${duration}ms`);
}

export default function () {
  syncBatch();
}
