# K6 Performance Tests

Performance tests for the ReadlePress API using [k6](https://k6.io/).

## Prerequisites

Install k6:

```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D68
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6

# Docker
docker pull grafana/k6
```

Ensure the ReadlePress API is running:

```bash
cd /workspace && npm run dev
```

## Running Tests

### API Load Test

Tests login, student listing, mastery summary, and competency listing under load (up to 1000 VUs).

```bash
k6 run tests/performance/api-load.js
```

Thresholds:
- `http_req_duration` p(95) < 800ms, p(99) < 2000ms
- `http_req_failed` rate < 1%

### Year-Close Performance

Tests the year-close completeness check and per-student aggregation performance.

```bash
k6 run tests/performance/year-close.js
```

Thresholds:
- Completeness check: p(95) < 30s
- Aggregation per student: p(95) < 5s

### Offline Sync Load

Tests offline capture sync with simultaneous teachers and batch sizes up to 100 observations.

```bash
k6 run tests/performance/sync-load.js
```

Thresholds:
- 100 observations sync: < 30s
- Error rate: < 5%

## Environment Variables

Override defaults with environment variables:

```bash
k6 run -e BASE_URL=http://staging.example.com/api/v1 \
       -e TEST_EMAIL=teacher@school.example.com \
       -e TEST_PASSWORD=TeacherPass123! \
       tests/performance/api-load.js
```

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_URL` | `http://localhost:3000/api/v1` | API base URL |
| `TEST_EMAIL` | `teacher@school.example.com` | Test user email |
| `TEST_PASSWORD` | `TeacherPass123!` | Test user password |
| `PRINCIPAL_EMAIL` | `principal@school.example.com` | Principal email (year-close tests) |
| `PRINCIPAL_PASSWORD` | `PrincipalPass123!` | Principal password |

## Interpreting Results

k6 outputs threshold pass/fail status and detailed metrics. Key metrics to watch:

- **http_req_duration**: Response time distribution
- **http_req_failed**: Error rate
- **Custom trends**: `login_duration`, `student_list_duration`, `mastery_summary_duration`, `sync_batch_duration`

Results can be exported to InfluxDB, Datadog, or Grafana Cloud for dashboards:

```bash
k6 run --out influxdb=http://localhost:8086/k6 tests/performance/api-load.js
```
