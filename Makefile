.DEFAULT_GOAL := up
.PHONY: help

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
	@wget -q --show-progress https://github.com/forkbombeu/ncr/releases/latest/download/ncr
	@chmod +x ./ncr
	@echo "📦 Setup is done!"

up: ncr ## 🚀 Up & run the project
	./ncr -p 3000 --hostname $(hn) -z wallet

# TODO: as soon as live-directory supports symlink to folder switch to symlink intead of cp
test/didroom_microservices:
	git clone https://github.com/forkbombeu/didroom_microservices test/didroom_microservices
	cp .env.test .env

test: api-test unit-test

unit-test: ncr test/didroom_microservices
	@./ncr -p 3000 -z test/didroom_microservices/authz_server --public-directory test/didroom_microservices/tests/public/authz_server & echo $$! > .test.authz_server.pid
	@./ncr -p 3001 -z test/didroom_microservices/credential_issuer --public-directory test/didroom_microservices/tests/public/credential_issuer & echo $$! > .test.credential_issuer.pid
	@./ncr -p 3002 -z ./wallet & echo $$! > .test.mobile_zencode.pid
	@./ncr -p 3003 -z test/didroom_microservices/relying_party --public-directory test/didroom_microservices/tests/public/relying_party & echo $$! > .test.relying_party.pid
	@./ncr -p 3366 -z test/didroom_microservices/tests/test_push_server & echo $$! > .test.push_server.pid
	sleep 5
	@git submodule update --init --recursive
	@./test/bats/bin/bats test/wallet.bats
	@kill `cat .test.credential_issuer.pid` && rm .test.credential_issuer.pid
	@kill `cat .test.authz_server.pid` && rm .test.authz_server.pid
	@kill `cat .test.mobile_zencode.pid` && rm .test.mobile_zencode.pid
	@kill `cat .test.relying_party.pid` && rm .test.relying_party.pid
	@kill `cat .test.push_server.pid` && rm .test.push_server.pid

api-test: ncr test/didroom_microservices
	@./ncr -p 3000 -z test/didroom_microservices/authz_server --public-directory test/didroom_microservices/tests/public/authz_server & echo $$! > .test.authz_server.pid
	@./ncr -p 3001 -z test/didroom_microservices/credential_issuer --public-directory test/didroom_microservices/tests/public/credential_issuer & echo $$! > .test.credential_issuer.pid
	@./ncr -p 3002 -z ./wallet & echo $$! > .test.mobile_zencode.pid
	@./ncr -p 3003 -z test/didroom_microservices/relying_party --public-directory test/didroom_microservices/tests/public/relying_party & echo $$! > .test.relying_party.pid
	@./ncr -p 3004 -z ./verifier & echo $$! > .test.verifier.pid
	@./ncr -p 3366 -z test/didroom_microservices/tests/test_push_server & echo $$! > .test.push_server.pid
	sleep 5
	@npx stepci run test/test_api.yml
	@kill `cat .test.credential_issuer.pid` && rm .test.credential_issuer.pid
	@kill `cat .test.authz_server.pid` && rm .test.authz_server.pid
	@kill `cat .test.mobile_zencode.pid` && rm .test.mobile_zencode.pid
	@kill `cat .test.relying_party.pid` && rm .test.relying_party.pid
	@kill `cat .test.verifier.pid` && rm .test.verifier.pid
	@kill `cat .test.push_server.pid` && rm .test.push_server.pid

clean:
	rm -rf test/didroom_microservices
