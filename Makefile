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

tests-well-known: tmp := $(shell mktemp)
tests-well-known: DM_PATH= test/didroom_microservices
tests-well-known:
# as
	@jq '."well-known_path" = "tests/public/authz_server/.well-known/oauth-authorization-server"' ${DM_PATH}/authz_server/.autorun/identity.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/authz_server/.autorun/identity.keys.json
	@jq '."well-known_path" = "tests/public/authz_server/.well-known/oauth-authorization-server"' ${DM_PATH}/authz_server/par.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/authz_server/par.keys.json
	@jq '."well-known_path" = "tests/public/authz_server/.well-known/oauth-authorization-server"' ${DM_PATH}/authz_server/token.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/authz_server/token.keys.json
	@jq '."well-known_path" = "tests/public/authz_server/.well-known/oauth-authorization-server"' ${DM_PATH}/authz_server/introspection.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/authz_server/introspection.keys.json
	@jq '."well-known_path" = "tests/public/authz_server/.well-known/oauth-authorization-server"' ${DM_PATH}/authz_server/ru_to_ac.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/authz_server/ru_to_ac.keys.json
	@jq '."well-known_path" = "tests/public/authz_server/.well-known/oauth-authorization-server"' ${DM_PATH}/authz_server/ru_to_toc.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/authz_server/ru_to_toc.keys.json
# ci
	@jq '."well-known_path" = "tests/public/credential_issuer/.well-known/openid-credential-issuer"' ${DM_PATH}/credential_issuer/credential.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/credential_issuer/credential.keys.json
	@jq '."well-known_path" = "tests/public/credential_issuer/.well-known/openid-credential-issuer"' ${DM_PATH}/credential_issuer/.autorun/identity.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/credential_issuer/.autorun/identity.keys.json
# rp
	@jq '."well-known_path" = "tests/public/relying_party/.well-known/openid-relying-party"' ${DM_PATH}/relying_party/verify.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/relying_party/verify.keys.json
	@jq '."well-known_path" = "tests/public/relying_party/.well-known/openid-relying-party"' ${DM_PATH}/relying_party/.autorun/identity.keys.json > ${tmp} && mv ${tmp} ${DM_PATH}/relying_party/.autorun/identity.keys.json
	@rm -f ${tmp}

test/didroom_microservices: tmp := $(shell mktemp)
test/didroom_microservices:
	git clone https://github.com/forkbombeu/didroom_microservices test/didroom_microservices
# custom code
	@for f in test/didroom_microservices/authz_server/custom_code/*.example; do \
		name=$$(echo $$f | rev | cut -d'.' -f2- | rev); \
		cp $$f $${name}; \
	done;
	@for f in test/didroom_microservices/credential_issuer/custom_code/*.example; do \
		name=$$(echo $$f | rev | cut -d'.' -f2- | rev); \
		cp $$f $${name}; \
	done;
	@cd test/didroom_microservices; make authorize AUTHZ_FILE=tests/public/authz_server/authorize; cd -
	@jq '.precondition=".authorize"' test/didroom_microservices/tests/public/authz_server/authorize.metadata.json > ${tmp} && mv ${tmp} test/didroom_microservices/tests/public/authz_server/authorize.metadata.json
# verifier
	@jq '.firebase_url="http://localhost:3366/verify-credential"' test/didroom_microservices/relying_party/verify.keys.json > ${tmp} && mv ${tmp} test/didroom_microservices/relying_party/verify.keys.json
	cp .env.test .env
	cp .env.test test/didroom_microservices/
	cp ncr test/didroom_microservices/

test: api-test unit-test

unit-test: ncr test/didroom_microservices tests-well-known
	@cd test/didroom_microservices; ./ncr -p 3000 -z authz_server --public-directory tests/public/authz_server & echo $$! > ../../.test.authz_server.pid; cd -
	@cd test/didroom_microservices; ./ncr -p 3001 -z credential_issuer --public-directory tests/public/credential_issuer & echo $$! > ../../.test.credential_issuer.pid; cd -
	@./ncr -p 3002 -z ./wallet & echo $$! > .test.mobile_zencode.pid
	@cd test/didroom_microservices; ./ncr -p 3003 -z relying_party --public-directory tests/public/relying_party & echo $$! > ../../.test.relying_party.pid; cd -
	@cd test/didroom_microservices; ./ncr -p 3366 -z tests/test_push_server & echo $$! > ../../.test.push_server.pid; cd -
	@for port in 3000 3001 3002 3003 3366; do \
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
	@kill `cat .test.credential_issuer.pid` && rm .test.credential_issuer.pid
	@kill `cat .test.authz_server.pid` && rm .test.authz_server.pid
	@kill `cat .test.mobile_zencode.pid` && rm .test.mobile_zencode.pid
	@kill `cat .test.relying_party.pid` && rm .test.relying_party.pid
	@kill `cat .test.push_server.pid` && rm .test.push_server.pid

api-test: ncr test/didroom_microservices tests-well-known
# modify wallet contract to not use capacitor
	@cat wallet/ver_qr_to_info.zen | sed "s/.*Given I connect to 'pb_url' and start capacitor pb client.*/Given I connect to 'pb_url' and start pb client\nGiven I send my_credentials 'my_credentials' and login/" > wallet/temp_ver_qr_to_info.zen
	@cp wallet/ver_qr_to_info.keys.json wallet/temp_ver_qr_to_info.keys.json
	@cp wallet/ver_qr_to_info.schema.json wallet/temp_ver_qr_to_info.schema.json
# start tests
	@cd test/didroom_microservices; ./ncr -p 3000 -z authz_server --public-directory tests/public/authz_server & echo $$! > ../../.test.authz_server.pid; cd -
	@cd test/didroom_microservices; ./ncr -p 3001 -z credential_issuer --public-directory tests/public/credential_issuer & echo $$! > ../../.test.credential_issuer.pid; cd -
	@./ncr -p 3002 -z ./wallet & echo $$! > .test.mobile_zencode.pid
	@cd test/didroom_microservices; ./ncr -p 3003 -z relying_party --public-directory tests/public/relying_party & echo $$! > ../../.test.relying_party.pid; cd -
	@./ncr -p 3004 -z ./verifier & echo $$! > .test.verifier.pid
	@cd test/didroom_microservices; ./ncr -p 3366 -z tests/test_push_server & echo $$! > ../../.test.push_server.pid; cd -
	@for port in 3000 3001 3002 3003 3004 3366; do \
		timeout --foreground 30s bash -c 'port=$$1; until nc -z localhost $$port; do \
			echo "Port $$port is not yet reachable, waiting..."; \
			sleep 1; \
		done' _ "$$port" || { \
			echo "Timeout while waiting for port $$port to be reachable"; \
			exit 1; \
		}; \
	done
	@npx stepci run test/test_api.yml
	@kill `cat .test.credential_issuer.pid` && rm .test.credential_issuer.pid
	@kill `cat .test.authz_server.pid` && rm .test.authz_server.pid
	@kill `cat .test.mobile_zencode.pid` && rm .test.mobile_zencode.pid
	@kill `cat .test.relying_party.pid` && rm .test.relying_party.pid
	@kill `cat .test.verifier.pid` && rm .test.verifier.pid
	@kill `cat .test.push_server.pid` && rm .test.push_server.pid
	@rm wallet/temp_ver_qr_to_info.zen wallet/temp_ver_qr_to_info.keys.json wallet/temp_ver_qr_to_info.schema.json

clean:
	rm -rf test/didroom_microservices
