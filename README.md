# mTLS test harness for Caddy and Traefik

Certificates will all generate on first run.

Some customization can be done by overriding HOSTNAME, USER, and PASSWORD. Otherwise defaults values will be used.

## Client setup

Clients must install the client certificates to present to the server. This can be done by grabbing the file from `./client_certs/<USER>/`, or by using Caddy. Once you run `make run_caddy`, you can download the cert from `client_setup.$HOSTNAME`, after logging in with the `$USER` and `$PASSWORD` values that are shown on your screen.

## Servers
Run each server, one at a time, by using `make run_caddy` or `make run_traefik`. Once run, you can verify authentication using `auth_test.$HOSTNAME`.
