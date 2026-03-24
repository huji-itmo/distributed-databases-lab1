pg_conftool set port 9213

export MAX_CONNECTIONS=$((150))

pg_conftool set max_connections $MAX_CONNECTIONS
pg_conftool set shared_buffers 512MB
pg_conftool set temp_buffers 8MB
pg_conftool set work_mem 4MB
pg_conftool set checkpoint_timeout 5min
pg_conftool set effective_cache_size 256MB
pg_conftool set fsync on
pg_conftool set commit_delay 0
pg_conftool set hba_file $(pwd)/pg_hba.conf