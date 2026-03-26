include .env

.PHONY: is_ready forward

configure: create_cluster start apply_config

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
	goose postgres ${LOCAL_CONNECTION_URL} -dir "tpc-c-migrations" create initial sql

tpc-c-up:
	goose postgres ${LOCAL_CONNECTION_URL} -dir "tpc-c-migrations" up

tpc-c-down:
	goose postgres ${LOCAL_CONNECTION_URL} -dir "tpc-c-migrations" down
