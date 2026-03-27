# PostgreSQL Theory and Practice

## 1. Initializing a Database Cluster (`initdb`)

### What it does
`initdb` creates a new PostgreSQL database cluster - a collection of databases that are managed by a single server instance.

### Syntax
```bash
initdb -D /path/to/data/directory
```

### Key options
- `-D`: Data directory path (PGDATA)
- `-A trust`: Disable password authentication for local connections (useful for testing)
- `-E UTF8`: Set default encoding (default is UTF8)
- `--locale=ru_RU.UTF-8`: Set locale

### What gets created
- `postgresql.conf` - Main configuration file
- `pg_hba.conf` - Client authentication rules
- `pg_wal/` - Write-Ahead Log directory
- `base/` - Database files
- `global/` - Cluster-wide tables
- `pg_dynshmem/` - Dynamic shared memory
- `pg_notify/` - LISTEN/NOTIFY state

### Example
```bash
pg_ctl -D /var/db/postgres4/yhv53 initdb -o '-A trust'
```

---

## 2. Starting and Stopping the Server

### Starting
```bash
# Start in background with log file
pg_ctl -D /var/db/postgres4/yhv53 start -l /var/db/postgres4/yhv53/postgresql.log

# Or just
pg_ctl -D /var/db/postgres4/yhv53 start
```

### Stopping
```bash
# Fast shutdown (wait for clients to disconnect)
pg_ctl -D /var/db/postgres4/yhv53 stop

# Immediate shutdown (forceful)
pg_ctl -D /var/db/postgres4/yhv53 stop -m fast

# Immediate (like kill -9)
pg_ctl -D /var/db/postgres4/yhv53 stop -m immediate
```

### Restarting
```bash
pg_ctl -D /var/db/postgres4/yhv53 restart

# Or reload config without restart
pg_ctl -D /var/db/postgres4/yhv53 reload
```

### Checking status
```bash
pg_ctl -D /var/db/postgres4/yhv53 status
```

---

## 3. Creating Users and Databases

### Create User
```sql
CREATE USER username WITH PASSWORD 'password';
```

### Create User with SUPERUSER (admin rights)
```sql
CREATE USER admin WITH PASSWORD 'password' SUPERUSER;
```

### Create Database
```sql
CREATE DATABASE dbname;
```

### Create Database owned by specific user
```sql
CREATE DATABASE dbname OWNER username;
```

### Drop User/Database
```sql
DROP USER username;
DROP DATABASE dbname;
```

### Shell commands
```bash
# Create user
createuser -P username

# Create database
createdb -O owner dbname
```

---

## 4. Granting Permissions

### Grant basic privileges
```sql
-- Grant CONNECT on database
GRANT CONNECT ON DATABASE dbname TO user;

-- Grant SELECT on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO user;

-- Grant specific table
GRANT SELECT, INSERT, UPDATE, DELETE ON table_name TO user;

-- Grant sequence (for auto-increment)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO user;
```

### Grant schema privileges
```sql
GRANT USAGE ON SCHEMA public TO user;
GRANT CREATE ON SCHEMA public TO user;
```

### Making privileges permanent for future tables
```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT ON TABLES TO user;
```

### Common privilege types
- `SELECT` - Read data
- `INSERT` - Add data
- `UPDATE` - Modify data
- `DELETE` - Remove data
- `TRUNCATE` - Delete all rows
- `REFERENCES` - Create foreign keys
- `TRIGGER` - Create triggers
- `CREATE` - Create objects in schema
- `CONNECT` - Connect to database
- `TEMPORARY` - Create temporary tables

### Revoke
```sql
REVOKE INSERT ON table_name FROM user;
```

---

## 5. Configuration Files

### `postgresql.conf` - Main Settings

Key parameters:
```conf
# Connection
listen_addresses = 'localhost'  # What IPs to listen on
port = 5432                    # Port number
max_connections = 100          # Max concurrent connections

# Memory
shared_buffers = 128MB         # PostgreSQL cache
work_mem = 4MB                 # Memory per sort/hash
temp_buffers = 8MB             # Temp tables per session

# Write-Ahead Log
wal_level = replica            # minimal, replica, logical
fsync = on                     # Force sync to disk
synchronous_commit = on        # Wait for WAL write
commit_delay = 0               # Group commit (microseconds)

# Checkpoint
checkpoint_timeout = 5min      # Time between checkpoints
checkpoint_completion_target = 0.9

# Query Tuning
effective_cache_size = 4GB    # Planner's estimate
random_page_cost = 4.0         # 1.0 for SSD, 4.0 for HDD
effective_io_concurrency = 1  # Parallel I/O operations

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
```

### `pg_hba.conf` - Authentication

Format:
```
# TYPE  DATABASE  USER  ADDRESS  METHOD
```

Examples:
```conf
# Local socket - trust (no password)
local  all  all  trust

# Local TCP - trust
host  all  all  127.0.0.1/32  trust

# Local TCP - password (MD5)
host  all  all  127.0.0.1/32  md5

# Remote - password
host  all  all  0.0.0.0/0  md5
host  all  all  ::/0  md5

# Replication
local  replication  all  trust
host  replication  all  127.0.0.1/32  md5
```

Methods:
- `trust` - No password required
- `reject` - Reject always
- `md5` - Password (MD5 hash)
- `scram-sha-256` - Modern password (SHA-256)
- `peer` - OS username matching

---

## 6. ALTER SYSTEM (Dynamic Configuration)

Instead of editing postgresql.conf directly:
```sql
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET max_connections = 200;
```

This writes to `postgresql.auto.conf` and persists across restarts.

Reload or restart to apply:
```sql
-- Reload (for most settings)
SELECT pg_reload_conf();

-- Restart (for shared_buffers, max_connections, etc.)
-- Requires pg_ctl restart
```

---

## 7. Key psql Commands

```bash
# Connect to database
psql -h localhost -U user -d database -p port

# List databases
\l

# List tables
\dt

# List users/roles
\du

# Describe table
\d table_name

# Execute SQL from file
psql -f script.sql

# Quit
\q
```

---

## 8. Process Architecture

```
postgres (main process)
├── checkpointer (writes WAL to disk)
├── background writer (flushes shared_buffers)
├── walwriter (writes WAL)
├── autovacuum (cleanup)
├── stats collector (statistics)
└── worker processes (for each connection)
```

---

## 9. WAL (Write-Ahead Log)

- WAL is a transaction log - all changes are written here first
- `fsync=off` disables syncing to disk (DANGEROUS but fast)
- WAL enables crash recovery and replication
- Checkpoint = point where all dirty pages are written to data files

---

## 10. Transaction ACID Properties

| Property | Description | PostgreSQL Implementation |
|----------|-------------|---------------------------|
| **Atomicity** | All or nothing | WAL + transaction log |
| **Consistency** | Valid state | Constraints, triggers, FK |
| **Isolation** | Concurrent看不到 | MVCC (Multi-Version Concurrency Control) |
| **Durability** | Committed = saved | WAL + fsync |

---

## 11. MVCC (Multi-Version Concurrency Control)

- Readers don't block writers
- Writers don't block readers
- Each transaction sees "snapshot" of data
- Old versions cleaned by VACUUM
- `xmin` / `xmax` fields in tuple header

---

## 12. Common Performance Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Too many connections** | "too many clients" | Connection pooling (PgBouncer) |
| **Missing indexes** | Slow queries | ANALYZE + CREATE INDEX |
| **fsync enabled** | Slow writes | fsync=off (benchmark only!) |
| **Full table scans** | High latency | Indexes, work_mem |
| **Bloat** | Large table size | VACUUM,VACUUM FULL |
| **Long queries** | High load | EXPLAIN ANALYZE |

---

## 13. EXPLAIN ANALYZE

```sql
EXPLAIN ANALYZE SELECT * FROM table WHERE id = 1;
```

Output shows:
- Planning time
- Execution time
- Actual rows
- Loops
- Which indexes used

Key terms:
- **Seq Scan** - Full table scan (bad)
- **Index Scan** - Using index (good)
- **Index Only Scan** - Using index, no table access (best)
- **Bitmap Heap Scan** - Combines multiple index hits
