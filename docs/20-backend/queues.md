# Backend Queues — ЧтоХочу

> **Status:** Authoritative backend queue configuration document. See also
> [`architecture.md`](./architecture.md) and [`ADR-007-redis.md`](../adr/ADR-007-redis.md).

## 1. Overview

Queues handle async and non-critical work: push notifications, email, image
processing, and broadcast dispatch. The queue backend is **Redis**, and workers are
managed by **Laravel Horizon**. Queues MUST NOT be used for critical business
mutations — those happen synchronously inside a PostgreSQL transaction.

## 2. Queue Configuration

The queue connection is configured in `config/queue.php` and driven by environment
variables:

```env
QUEUE_CONNECTION=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=null
```

Horizon is configured in `config/horizon.php` with named queues and worker pools:

```php
'supervisors' => [
    [
        'name' => 'default',
        'connection' => 'redis',
        'queue' => ['default', 'notifications', 'broadcasts', 'images'],
        'balance' => 'auto',
        'maxProcesses' => 4,
        'maxTime' => 0,
        'maxJobs' => 0,
    ],
],
```

## 3. Queue Names

| Queue | Purpose |
|-------|---------|
| `default` | General async work |
| `notifications` | Push notifications (FCM), email |
| `broadcasts` | Realtime broadcast dispatch |
| `images` | Image processing / uploads |

Separating queues by concern prevents one kind of job (e.g. image processing) from
starving time-sensitive work (e.g. broadcasts).

## 4. Worker Startup

In the Docker stack, a dedicated `worker` container runs Horizon:

```bash
php artisan horizon
```

Horizon manages the worker processes according to `config/horizon.php`. In production,
Horizon runs under a process supervisor (e.g. Supervisor or the platform's process
manager) so it restarts on failure.

For one-off manual work locally:

```bash
php artisan queue:work --queue=notifications,broadcasts,default
```

## 5. Retries

| Setting | Default | Notes |
|---------|---------|-------|
| `tries` | 3 | Max attempts before a job is failed |
| `backoff` | Exponential | 5s, 10s, 20s by default |
| `timeout` | 60s | Per-job PHP timeout |
| `retry_after` | 90s | Redis release timeout |

Jobs MAY override `tries` and `backoff` per class. A job that performs side effects
(e.g. sending a push notification) MUST be **idempotent** so that a retry does not
duplicate the side effect, or **unique** so that duplicate dispatches are coalesced.

## 6. Failed Jobs

Failed jobs are retained for inspection. Horizon provides a dashboard at `/horizon`
(dev/staging) showing failed, pending, and recent jobs.

```bash
# Retry all failed jobs
php artisan horizon:retry

# Retry a specific job
php artisan horizon:retry <jobId>

# Forget a failed job
php artisan queue:forget <jobId>

# Flush all failed jobs
php artisan queue:flush
```

Failed jobs that represent a real bug should be reproduced with a test before being
retried at scale.

## 7. Horizon

Horizon is the queue dashboard and worker manager. It provides:

- Real-time throughput, latency, and queue depth metrics.
- Failed job inspection and retry.
- Job-specific configuration (tries, timeout, tags).

Horizon is available at `/horizon` in local and staging. In production, access is
restricted (it is an internal dashboard, not a user-facing surface).

> **Note:** Horizon stores metrics and recent job data in Redis. This data is
> ephemeral and MUST NOT be treated as authoritative business state.

## 8. Debugging

| Symptom | Check |
|---------|-------|
| Jobs not processing | `worker` container running? `make logs-svc=worker` |
| Jobs stuck in queue | Redis reachable from worker? `redis-cli ping` |
| Duplicate side effects | Job not idempotent / not unique — fix the job |
| Jobs failing repeatedly | `make logs-svc=worker` or Horizon failed-jobs tab; reproduce with a test |
| Broadcast not delivered | `broadcasts` queue backed up? Reverb reachable? See [`realtime.md`](./realtime.md) |

## 9. Rules

- Queues are for async / non-critical work only (AGENTS.md §7).
- Jobs with side effects MUST be idempotent or unique.
- Redis is the queue backend; Redis is infrastructure only.
- Broadcasts are dispatched after the PostgreSQL transaction commits.
- Horizon metrics are ephemeral; PostgreSQL is the source of truth.

## 10. Non-Goals

- No Kafka, RabbitMQ, or SQS without an approved ADR (AGENTS.md §16).
- No synchronous business mutations on the queue.
- No authoritative business state in Redis or Horizon.
