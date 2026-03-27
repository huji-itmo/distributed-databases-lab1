include .env


TPC_C_MIGRATIONS_DIR 	:= ./tpc-c/tpc-c-migrations
GOOSE_TABLE    			:= goose_migrations
GOOSE_DRIVER   			:= postgres
TPC_C_GOOSE_ENV			:= GOOSE_DRIVER=$(GOOSE_DRIVER) GOOSE_DBSTRING=${DB_DSN} GOOSE_MIGRATION_DIR=$(TPC_C_MIGRATIONS_DIR)

.PHONY: is_ready forward create_cluster

configure: is_ready apply_config

create_cluster: destroy_cluster
	bash scripts/create_cluster.sh
	sleep 2

apply_config:
	bash scripts/apply_config.sh

start:
	bash scripts/start_postgres.sh

stop:
	bash scripts/stop_postgres.sh

is_ready:
	bash scripts/is_ready.sh

destroy_cluster:
	rm -rf CLUSTER_FOLDER

sync:
	bash scripts/sync.sh

forward:
	ssh -L 5432:localhost:${PORT} -N helios_pg

goose_init:
	${TPC_C_GOOSE_ENV} goose -table $(GOOSE_TABLE)} create initial sql

.PHONY: tpc-c-up
tpc-c-up:
	${TPC_C_GOOSE_ENV} goose -table $(GOOSE_TABLE) up

.PHONY: tpc-c-down
tpc-c-down:
	${TPC_C_GOOSE_ENV} goose -table $(GOOSE_TABLE) down

.PHONY: tpc-c-status
tpc-c-status:
	${TPC_C_GOOSE_ENV} goose -table $(GOOSE_TABLE) status

.PHONY: tpc-c-seed
tpc-c-seed: tpc-c-up
	  .venv/bin/python tpc-c/seed_tpc_c.py

.PHONY: clean-db
clean-db:
	  .venv/bin/python tpc-c/delete_all.py

.PHONY: disable-sync
disable-sync:
	bash scripts/disable_sync.sh

.PHONY: enable-sync
enable-sync:
		bash scripts/enable_sync.sh

.PHONY: bench
bench:
	pgbench -h 127.0.0.1 -U postgres4 -d postgres \
		-p 9213 \
		-l \
		-n \
        -f "tpc-c/tpc-c-new-order.sql" \
        -c 4 -j 8 -T 60 \
		-M prepared -P 5 \
		> res.txt
