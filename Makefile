.PHONY: build up down restart reset logs url check shell clean

build:
	docker compose build

up:
	mkdir -p workspace
	docker compose up -d --build
	@$(MAKE) --no-print-directory _wait-url

reset:
	docker compose down
	mkdir -p workspace
	docker compose up -d
	@$(MAKE) --no-print-directory _wait-url

_wait-url:
	@echo "Waiting for Colab runtime to start..."
	@for i in $$(seq 1 30); do \
		if docker compose exec -T colab test -f /tmp/colab_connect_url 2>/dev/null; then \
			echo ""; \
			echo "Connect URL:"; \
			docker compose exec -T colab cat /tmp/colab_connect_url; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Timed out waiting for URL. Check logs with: make logs"

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f colab

url:
	@docker compose exec -T colab cat /tmp/colab_connect_url

check:
	docker compose exec -T colab colab-selfcheck

shell:
	docker compose exec colab bash

clean:
	docker compose down --rmi local
