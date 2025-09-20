.DEFAULT_GOAL := up
.PHONY: help

NCR_VERSION := 1.43.1
NCR_URL := https://github.com/ForkbombEu/ncr/releases/download/v$(NCR_VERSION)/ncr

hn=$(shell hostname)

# detect the operating system
OSFLAG 				:=
ifneq ($(OS),Windows_NT)
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OSFLAG += LINUX
	endif
	ifeq ($(UNAME_S),Darwin)
		OSFLAG += OSX
	endif
endif

WGET := $(shell command -v wget 2> /dev/null)

all:
ifndef WGET
    $(error "🥶 wget is not available! Please retry after you install it")
endif

help: ## 🛟 Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-7s\033[0m %s\n", $$1, $$2}'

ncr: ## 📦 Install and setup the server
	@if [ ! -x ./ncr ] || [ "$$(./ncr -v)" != "${NCR_VERSION}" ]; then \
		wget -q --show-progress $(NCR_URL) -O ncr; \
		chmod +x ./ncr; \
	fi
	@echo "📦 Setup is done! Ncr version ${NCR_VERSION} installed"

up: ncr ## 🚀 Up & run the project
	./ncr -p 3000 --hostname $(hn) -z wallet

tests-well-known:
	@cd test/didroom_microservices && ./scripts/wk.sh setup && cd -;

test/didroom_microservices: tmp := $(shell mktemp)
test/didroom_microservices:
	$(info ⬇️  Cloning test/didroom_microservices)
	@git clone https://github.com/forkbombeu/didroom_microservices test/didroom_microservices --quiet
# custom code
	$(MAKE) -C test/didroom_microservices test_custom_code --no-print-directory
	@cp .env.test .env
	@cp ncr test/didroom_microservices/

test: api-test unit-test

unit-test: ncr test/didroom_microservices tests-well-known
	$(MAKE) -C test/didroom_microservices up --no-print-directory
	@./ncr -p 3003 -z ./wallet & echo $$! > .test.mobile_zencode.pid
	@for port in 3000 3001 3002 3003; do \
		timeout --foreground 30s bash -c 'port=$$1; until nc -z localhost $$port; do \
			echo "Port $$port is not yet reachable, waiting..."; \
			sleep 1; \
		done' _ "$$port" || { \
			echo "Timeout while waiting for port $$port to be reachable"; \
			exit 1; \
		}; \
	done
	@git submodule update --init --recursive
	@./test/bats/bin/bats test/wallet.bats
	@kill `cat test/didroom_microservices/.credential_issuer.pid` && rm test/didroom_microservices/.credential_issuer.pid
	@kill `cat test/didroom_microservices/.authz_server.pid` && rm test/didroom_microservices/.authz_server.pid
	@kill `cat test/didroom_microservices/.verifier.pid` && rm test/didroom_microservices/.verifier.pid
	@kill `cat .test.mobile_zencode.pid` && rm .test.mobile_zencode.pid

api-test: ncr test/didroom_microservices tests-well-known
# modify wallet contract to not use capacitor
	@cat wallet/ver_qr_to_info.zen | sed "s/.*Given I connect to 'pb_url' and start capacitor pb client.*/Given I connect to 'pb_url' and start pb client\nGiven I send my_credentials 'my_credentials' and login/" > wallet/temp_ver_qr_to_info.zen
	@cp wallet/ver_qr_to_info.keys.json wallet/temp_ver_qr_to_info.keys.json
	@cp wallet/ver_qr_to_info.schema.json wallet/temp_ver_qr_to_info.schema.json
# start tests
	$(MAKE) -C test/didroom_microservices up --no-print-directory
	@./ncr -p 3003 -z ./wallet & echo $$! > .test.mobile_zencode.pid
	@for port in 3000 3001 3002 3003; do \
		timeout --foreground 30s bash -c 'port=$$1; until nc -z localhost $$port; do \
			echo "Port $$port is not yet reachable, waiting..."; \
			sleep 1; \
		done' _ "$$port" || { \
			echo "Timeout while waiting for port $$port to be reachable"; \
			exit 1; \
		}; \
	done
	@npx stepci run test/test_api.yml
	@kill `cat test/didroom_microservices/.credential_issuer.pid` && rm test/didroom_microservices/.credential_issuer.pid
	@kill `cat test/didroom_microservices/.authz_server.pid` && rm test/didroom_microservices/.authz_server.pid
	@kill `cat test/didroom_microservices/.verifier.pid` && rm test/didroom_microservices/.verifier.pid
	@kill `cat .test.mobile_zencode.pid` && rm .test.mobile_zencode.pid
	@rm wallet/temp_ver_qr_to_info.zen wallet/temp_ver_qr_to_info.keys.json wallet/temp_ver_qr_to_info.schema.json

clean:
	rm -rf test/didroom_microservices
