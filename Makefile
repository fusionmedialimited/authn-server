ORG := keratin
PROJECT := authn-server
NAME := $(ORG)/$(PROJECT)
VERSION := TEST
MAIN := main.go

.PHONY: clean
clean:
	rm -rf dist

init:
	which ego > /dev/null || go get github.com/benbjohnson/ego/cmd/ego
	ego server/views

# Run the server
.PHONY: server
server: init
	docker-compose up -d redis
	DATABASE_URL=sqlite3://localhost/dev \
		REDIS_URL=redis://127.0.0.1:8701/11 \
		go run -ldflags "-X main.VERSION=$(VERSION)" $(MAIN)

# Run tests
.PHONY: test
test: init
	docker-compose up -d redis mysql postgres
	TEST_REDIS_URL=redis://127.0.0.1:8701/12 \
	  TEST_MYSQL_URL=mysql://root@127.0.0.1:8702/authnservertest \
	  TEST_POSTGRES_URL=postgres://postgres:password@127.0.0.1:8703/postgres?sslmode=disable \
	  go test -race ./...

.PHONY: redis-cluster-test
redis-cluster-test: init
	docker-compose -f docker-compose.cluster.yml up -d redis-cluster \
		redis-node-0 redis-node-1 redis-node-2 \
		redis-node-3 redis-node-4 redis-node-5 \
		postgres mysql
	docker-compose -f docker-compose.cluster.yml run redis-node-0 -- redis-cli -c -h redis-node-0 flushall
	docker-compose -f docker-compose.cluster.yml up --build --abort-on-container-exit test
	docker-compose -f docker-compose.cluster.yml stop

.PHONY: redis-sentinel-test
redis-sentinel-test: init
	docker-compose -f docker-compose.sentinel.yml up -d redis redis-sentinel postgres mysql
	docker-compose -f docker-compose.sentinel.yml run redis -- redis-cli -h redis flushall
	docker-compose -f docker-compose.sentinel.yml up --build --abort-on-container-exit test
	docker-compose -f docker-compose.sentinel.yml stop

# Run benchmarks
.PHONY: benchmarks
benchmarks:
	docker-compose up -d redis
	TEST_REDIS_URL=redis://127.0.0.1:8701/12 \
		go test -run=XXX -bench=. \
			github.com/keratin/authn-server/server/meta \
			github.com/keratin/authn-server/server/sessions

# Run migrations
.PHONY: migrate
migrate:
	docker-compose up -d redis
	DATABASE_URL=sqlite3://localhost/dev \
		REDIS_URL=redis://127.0.0.1:8701/11 \
		go run -ldflags "-X main.VERSION=$(VERSION)" $(MAIN) migrate

# Cut a release of the current version.
.PHONY: release
release:
	git push
	git tag v$(VERSION)
	git push --tags
	open https://github.com/$(NAME)/releases/tag/v$(VERSION)
