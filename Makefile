HOSTNAME ?= $(shell hostname)
PASSWORD ?= password
USER ?= user
HTTP_PORT ?= 80
HTTPS_PORT ?= 443

.PHONY: host_instructions
host_instructions:
	@echo "Make sure paths to client_setup.$(HOSTNAME) and auth_test.$(HOSTNAME) are pointing to this server. Eg."
	@echo "\techo \"127.0.0.1\t client_setup.$(HOSTNAME)\" | sudo tee -a /etc/hosts"
	@echo "\techo \"127.0.0.1\t auth_test.$(HOSTNAME)\" | sudo tee -a /etc/hosts"
	@echo ""
	@echo "To use a different hostname, run: 'env HOSTNAME=myhost make ...' instead"
	@echo ""

server_certs/mtls_ca.key: server_certs/mtls_ca.crt
server_certs/mtls_ca.crt:
	@mkdir -p server_certs
	openssl req -new -x509 -nodes -days 365 -subj "/CN=my-ca" \
		-keyout server_certs/mtls_ca.key \
		-out server_certs/mtls_ca.crt

server_certs/mtls_server.key:
	@mkdir -p server_certs
	openssl genrsa -out server_certs/mtls_server.key

server_certs/mtls_server.csr: server_certs/mtls_server.key
	openssl req -new -key server_certs/mtls_server.key \
		-subj "/CN=*.$(HOSTNAME)" \
		-out server_certs/mtls_server.csr

server_certs/mtls_server.crt: server_certs/mtls_server.csr server_certs/mtls_ca.crt
	openssl x509 -req \
		-in server_certs/mtls_server.csr \
		-CA server_certs/mtls_ca.crt \
		-CAkey server_certs/mtls_ca.key \
		-CAcreateserial \
		-days 365 \
		-out server_certs/mtls_server.crt

.PHONY: server_certs
server_certs: server_certs/mtls_server.crt

client_certs/$(USER):
	@mkdir -p client_certs/$(USER)

client_certs/$(USER)/$(USER).key: client_certs/$(USER)
	openssl genrsa -out client_certs/$(USER)/$(USER).key

client_certs/$(USER)/$(USER).csr: client_certs/$(USER)/$(USER).key
	openssl req -new -key client_certs/$(USER)/$(USER).key \
		-subj "/CN=user-$(USER)" -out client_certs/$(USER)/$(USER).csr

client_certs/$(USER)/$(USER).crt: client_certs/$(USER)/$(USER).csr server_certs/mtls_ca.key
	openssl x509 -req \
		-in client_certs/$(USER)/$(USER).csr \
		-CA server_certs/mtls_ca.crt \
		-CAkey server_certs/mtls_ca.key \
		-CAcreateserial \
		-days 365 \
		-out client_certs/$(USER)/$(USER).crt

.PHONY: client_certs
client_certs: client_certs/$(USER)/$(USER).crt

.PHONY: all_certs
all_certs: server_certs client_certs

.PHONY: user_instructions
user_instructions:
	@echo "***********************************"
	@echo "* Log in with $(USER):$(PASSWORD) *"
	@echo "***********************************"

.PHONY: run_caddy
run_caddy: host_instructions all_certs user_instructions
	docker run -p $(HTTP_PORT):80 -p $(HTTPS_PORT):443 \
		-e BASICAUTH_USER_HASH="$(USER) $(shell docker run --rm caddy caddy hash-password --plaintext "$(PASSWORD)")" \
		-v "$(shell pwd)/Caddyfile:/etc/caddy/Caddyfile" \
		-v "$(shell pwd)/server_certs:/server_certs" \
		-v "$(shell pwd)/client_certs:/client_certs" \
		caddy

.PHONY: run_traefik
run_traefik: host_instructions all_certs
	docker run -p $(HTTP_PORT):80 -p $(HTTPS_PORT):443 \
		-v /var/run/docker.sock:/var/run/docker.sock:ro \
		-v "$(shell pwd)/traefik.toml:/traefik.toml" \
		-v "$(shell pwd)/server_certs:/server_certs" \
		-v "$(shell pwd)/client_certs:/client_certs" \
		-l traefik.enable=true \
		-l "traefik.http.routers.traefikDash.rule=Host(`auth_test.$(HOSTNAME)`) \
		-l traefik.http.routers.traefikDash.service=api@internal \
		-l traefik.http.routers.traefikDash.middlewares=api@internal \
		-l traefik.http.routers.traefikDash.tls.options=client@file \
		traefik
