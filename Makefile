.PHONY: build up down restart reset logs url check shell clean _wait-url

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
	@for i in $$(seq 1 45); do \
		url=$$(docker compose exec -T colab bash -c ' \
			u="$$(cat /tmp/colab_connect_url 2>/dev/null || true)"; \
			t="$${u#*token=}"; \
			if [ -n "$$t" ] && [ "$$t" != "$$u" ] && \
			   curl -fsS "http://127.0.0.1:$${JUPYTER_PORT:-8080}/api/status?token=$$t" >/dev/null 2>&1; then \
				printf "%s\n" "$$u"; \
			fi' 2>/dev/null || true); \
		if [ -n "$$url" ]; then \
			echo ""; \
			echo "Connect URL:"; \
			echo "$$url"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "Timed out waiting for URL. Check logs with: make logs"; \
	exit 1

down:
	docker compose down

restart:
	docker compose restart
	@$(MAKE) --no-print-directory _wait-url

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
