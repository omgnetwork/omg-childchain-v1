.PHONY: list

HEX_URL    ?= https://repo.hex.pm/installs/1.8.0/hex-0.20.5.ez
HEX_SHA    ?= cb7fdddbc4e5051b403cfb5e874ceb5cb0ecbe981a2a1517b97f9f76c67d234692e901ff48ee10dc712f728ae6ed0a51b11b8bd65b5db5582896123de20e7d49
REBAR_URL  ?= https://repo.hex.pm/installs/1.0.0/rebar-2.6.2
REBAR_SHA  ?= ff1c5ddfce1fcfd73fd65b8bfc0ff1c13aefc2e98921d528cbc1f35e86c9caa1c9c4e848b9ce6404d9a81c50cfcf0e45dd0dddb23cd42708664c41fce6618900
REBAR3_URL ?= https://repo.hex.pm/installs/1.0.0/rebar3-3.5.1
REBAR3_SHA ?= 86e998642991d384e9a6d4f216552609496da0e6ec4eb235df5b8b637d078c1a118bc7cdab501d1d54d24e0b6642adf32cc0c43019d948304301ceef227bedfd

COMPOSE_FULL_SERVICES=-f ../../docker-compose.yml -f ../../docker-compose.feefeed.yml

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

clean:
	docker-compose $(COMPOSE_FULL_SERVICES) down && docker volume prune --force

start-services:
	cd ../../ && \
	SNAPSHOT=SNAPSHOT_MIX_EXIT_PERIOD_SECONDS_120 make init-contracts && \
	cd priv/perf/ && \
	docker-compose $(COMPOSE_FULL_SERVICES) up -d

stop-services:
	docker-compose $(COMPOSE_FULL_SERVICES) down

log-services:
	docker-compose $(COMPOSE_FULL_SERVICES) logs -f childchain feefeed watcher watcher_info geth

init:
	. scripts/generate_api_client.sh
	mix deps.get

test: # runs test against child chain and geth provided in test docker containers
	LOAD_TEST_FAUCET_PRIVATE_KEY=0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce mix test --trace

format-code-check-warnings:
	LOAD_TEST_FAUCET_PRIVATE_KEY=0xd885a307e35738f773d8c9c63c7a3f3977819274638d04aaf934a1e1158513ce MIX_ENV=test mix do compile --warnings-as-errors --ignore-module-conflict --force, test --exclude test

install-hex-rebar:
	mix archive.install ${HEX_URL} --force --sha512 ${HEX_SHA}
	mix local.rebar rebar ${REBAR_URL} --force --sha512 ${REBAR_SHA}
	mix local.rebar rebar3 ${REBAR3_URL} --force --sha512 ${REBAR3_SHA}