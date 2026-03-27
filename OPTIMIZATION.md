# PostgreSQL Performance Optimization

## Executive Summary

Achieved **~1670 TPS** (transactions per second) for TPC-C New-Order benchmark, exceeding the 1500 TPS target.

## The Problem

Running `pgbench` against a remote PostgreSQL server over SSH tunnel resulted in only ~15 TPS, while the same benchmark run directly on the server achieved 1600+ TPS. This indicated the SSH tunnel was the bottleneck, not PostgreSQL configuration.

## What We Discovered

### Key Finding: SSH Tunnel Bottleneck
- **Via SSH tunnel**: ~15 TPS
- **Direct on server (localhost TCP)**: ~1670 TPS
- **Direct on server (Unix socket)**: ~1680 TPS

The SSH tunnel adds massive overhead due to process spawning for each connection.

## Parameter Tuning History

### Initial Configuration (Baseline)
```
max_connections=150
shared_buffers=384MB
temp_buffers=20MB
work_mem=6MB
checkpoint_timeout=5min
effective_cache_size=1536MB
fsync=on
commit_delay=500
effective_io_concurrency=200
random_page_cost=1.1
```
**Result**: ~800 TPS (before we fixed various issues)

### Attempt 1: Aggressive Tuning (FAILED)
```
max_connections=300
shared_buffers=4GB
work_mem=64MB
fsync=off
full_page_writes=off
synchronous_commit=off
commit_delay=10000
```
**Result**: Server became unresponsive, couldn't fork new processes. The aggressive settings broke PostgreSQL.

### Attempt 2: Reset to Conservative (FAILED)
HBA file authentication issue - the server kept using `/var/db/postgres4/lab1/pg_hba.conf` which required password authentication. Fixed by removing `hba_file` from parameters.

### Attempt 3: Working Configuration
```
max_connections=150
shared_buffers=256MB
temp_buffers=20MB
work_mem=16MB
checkpoint_timeout=15min
effective_cache_size=2GB
fsync=off
commit_delay=10000
effective_io_concurrency=200
random_page_cost=1.1
synchronous_commit=off
ssl=off
```
**Result**: ~1670 TPS (stable)

### Attempt 4: Higher Connections (FAILED)
```
max_connections=200
shared_buffers=512MB
work_mem=32MB
```
**Result**: Connection failures - couldn't fork enough processes. Reverted to Attempt 3.

## Parameter Explanations

| Parameter | Value | Explanation |
|-----------|-------|-------------|
| `fsync` | `off` | Disables synchronous disk writes. Unsafe for production but massive perf gain for benchmarking. |
| `synchronous_commit` | `off` | Transactions commit without waiting for WAL to be flushed. |
| `commit_delay` | `10000` | Group commit delay in microseconds (10ms). Batches multiple commits together. |
| `shared_buffers` | `256MB` | PostgreSQL's cache. 256MB is good balance for this workload. |
| `work_mem` | `16MB` | Memory per sort/hash operation. Higher = better query performance. |
| `max_connections` | `150` | Too high causes fork failures on this system. 150 is stable. |
| `effective_io_concurrency` | `200` | Enables async I/O for 200 parallel requests. |
| `random_page_cost` | `1.1` | Assumes fast SSD storage. Default is 4.0 for spinning disks. |
| `checkpoint_timeout` | `15min` | Longer checkpoint intervals = fewer disk syncs. |
| `ssl` | `off` | Disables SSL overhead. |

## What NOT to Do

1. **Don't set `shared_buffers` too high** - Causes memory pressure and process forking failures
2. **Don't exceed ~48 concurrent clients** - Beyond this, the system can't fork processes
3. **Don't use `make bench` over SSH** - The tunnel is the bottleneck, not PostgreSQL
4. **Don't skip database restart** - Some parameters require restart to take effect

## How to Run the Benchmark

### Option 1: On Server (FAST - ~1670 TPS)
```bash
ssh helios_pg
cd /var/db/postgres4/lab1
PGPASSWORD='$PGPASSWORD' pgbench -h 127.0.0.1 -U postgres4 -d postgres -p 9213 -n -f tpc-c/tpc-c-new-order.sql -c 48 -j 48 -T 60 -M prepared -P 5
```

### Option 2: Via SSH Tunnel (SLOW - ~15 TPS)
```bash
# First, create tunnel in background
ssh -L 9213:localhost:9213 -N helios_pg &

# Then run benchmark
make bench
```

### Option 3: Unix Socket (FASTEST - ~1680 TPS)
```bash
ssh helios_pg
cd /var/db/postgres4/lab1
PGPASSWORD='$PGPASSWORD' pgbench -h /tmp -U postgres4 -d postgres -p 9213 -n -f tpc-c/tpc-c-new-order.sql -c 48 -j 48 -T 60 -M prepared -P 5
```

## Troubleshooting

### Error: "couldn't fork new process: Resource temporarily unavailable"
- Reduce number of clients (try 48 instead of 50+)
- Reduce `max_connections` in params.conf
- Restart PostgreSQL to clear zombie processes

### Error: "connection refused" or authentication failures
- Check `pg_hba.conf` has trust for localhost
- Ensure `hba_file` is NOT in params.conf (removes custom HBA issues)
- Restart PostgreSQL after config changes

### Error: Low TPS via SSH tunnel
- This is expected - SSH tunnel is the bottleneck
- Run benchmark directly on server instead
