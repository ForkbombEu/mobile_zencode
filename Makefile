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

wallet/didroom_microservices:
	git clone https://github.com/forkbombeu/didroom_microservices wallet/didroom_microservices

test: wallet/didroom_microservices ncr api-test unit-test

unit-test:
	@./ncr -p 3000 -z wallet --public-directory wallet/didroom_microservices/public & echo $$! > .test.ncr.pid
	@git submodule update --init --recursive
	sleep 2
	@./test/bats/bin/bats test/wallet.bats
	@kill `cat .test.ncr.pid` && rm .test.ncr.pid
	@rm -rf wallet/didroom_microservices

api-test:
	@./ncr -p 3000 -z wallet & echo $$! > .test.ncr.pid
	@npx stepci run test/test_api.yml
	@kill `cat .test.ncr.pid` && rm .test.ncr.pid

clean:
	rm -rf wallet/didroom_microservices
