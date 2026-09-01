# Local HTTPS Setup — ЧтоХочу

> **Status:** Authoritative guide for local TLS. See [`local-routing.md`](./local-routing.md)
> and [`docker.md`](./docker.md) for companion topics.

## 1. Why HTTPS Is Required Locally

Several platform features behave differently (or fail entirely) on plain HTTP. Running
the local environment over HTTPS from the start avoids surprises and matches
production.

| Requirement | Why HTTPS is needed |
|-------------|---------------------|
| **OAuth redirects** | VK / Yandex OAuth providers require HTTPS redirect URIs. Browsers block `http://` redirects for OAuth flows in many configurations. |
| **Secure cookies** | `Secure` cookies are only sent over HTTPS. Sanctum stateful domains and CSRF tokens rely on secure cookies for the public-web cabinet. |
| **WebSockets (WSS)** | Browsers may block `ws://` (insecure WebSocket) from `https://` pages (mixed-content). The realtime client must use `wss://`. |
| **Service workers** | Service workers (used by PWA-capable web apps) only register on HTTPS (or `localhost`). `*.chtohochu.test` is not `localhost`, so HTTPS is required. |
| **Mixed-content rules** | Serving the web apps over HTTPS while calling an HTTP API triggers mixed-content blocking. Everything must be HTTPS. |

## 2. Approach: mkcert Local CA

The project uses **mkcert** to create a locally-trusted certificate authority (CA) and
issue certificates for `*.chtohochu.test`. mkcert-generated certificates are trusted by
the local browser and OS once the mkcert root CA is installed.

This is preferable to self-signed certificates (which produce browser warnings and
require per-host exceptions) and to disabling TLS verification (which is unsafe and
masks real issues).

## 3. Prerequisites

Install mkcert and a certificate-building library:

**Ubuntu / Debian:**

```bash
sudo apt install libnss3-tools mkcert
```

If `mkcert` is not in your package manager, install from the
[releases page](https://github.com/FiloSottile/mkcert) or via Homebrew on macOS
(`brew install mkcert`).

## 4. Install the Local CA

```bash
mkcert -install
```

This creates a local root CA and installs it into the system trust store (and the
Firefox/NSS store where available). You will be prompted for your password to modify
the system trust store.

The CA is stored at `~/.local/share/mkcert/` and is unique to your machine. It is not
shared and must not be committed to the repository.

## 5. Trusting the CA on Ubuntu

On Ubuntu, `mkcert -install` places the root CA in:

```
/usr/local/share/ca-certificates/mkcert-rootCA.crt
```

and runs `update-ca-certificates`. To verify:

```bash
# List trusted CAs (should include mkcert)
trust list | grep -i mkcert

# Or check the file
ls -l /usr/local/share/ca-certificates/mkcert-rootCA.crt
```

If Firefox uses its own NSS store and `mkcert -install` did not add it (e.g. snap
Firefox), import the root CA manually:

```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," \
  -n "mkcert root CA" \
  -i "$(mkcert -CAROOT)/rootCA.pem"
```

Then restart Firefox.

## 6. Generating Certificates for `*.chtohochu.test`

From the repository root (or the `infrastructure/` certs directory):

```bash
mkcert "chtohochu.test" "*.chtohochu.test" localhost 127.0.0.1 ::1
```

This produces two files:

```
chtohochu.test+1.pem      # certificate
chtohochu.test+1-key.pem  # private key
```

Rename them for clarity and place them in the Traefik certs volume:

```bash
mkdir -p infrastructure/certs
mv chtohochu.test+1.pem      infrastructure/certs/local.crt
mv chtohochu.test+1-key.pem  infrastructure/certs/local.key
```

> **Never commit** `infrastructure/certs/` to the repository. Add it to `.gitignore`.
> The private key is machine-local.

The `make certs` Make target automates generation and placement.

## 7. Traefik TLS Configuration

Traefik loads the certificate and key from the certs volume and presents them for all
`*.chtohochu.test` requests.

### 7.1 docker-compose.yml (Traefik service)

```yaml
services:
  traefik:
    image: traefik:v3
    command:
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--providers.file.watch=true"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./infrastructure/traefik/dynamic:/etc/traefik/dynamic:ro
      - ./infrastructure/certs:/certs:ro
```

### 7.2 Dynamic TLS configuration

`infrastructure/traefik/dynamic/tls.yml`:

```yaml
tls:
  certificates:
    - certFile: /certs/local.crt
      keyFile: /certs/local.key
  stores:
    default:
      defaultCertificate:
        certFile: /certs/local.crt
        keyFile: /certs/local.key
```

Traefik watches this file and reloads on change. With the wildcard certificate in the
default store, every `*.chtohochu.test` host is served over HTTPS without per-host
configuration.

## 8. Client Configuration

Client apps connect to the HTTPS endpoints:

| App | Base URL |
|-----|----------|
| Flutter | `https://api.chtohochu.test/api/v1` |
| public-web | `https://api.chtohochu.test/api/v1` |
| seller | `https://api.chtohochu.test/api/v1` |
| admin | `https://api.chtohochu.test/api/v1` |
| WebSocket | `wss://ws.chtohochu.test/app/<key>` |

Because the mkcert CA is trusted locally, no `allowInsecure` / `badCertificateCallback`
overrides are needed in Flutter or the browser. Do not disable TLS verification in
client code — if a certificate is rejected, fix the CA trust, not the client.

## 9. Renewal and Rotation

mkcert certificates are valid for ~2.5 years. When a certificate expires:

```bash
make certs        # regenerate
make restart-svc=traefik
```

The CA itself does not expire on a short horizon; rotating the CA requires
`mkcert -uninstall` then `mkcert -install` and re-issuing all certificates.

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `NET::ERR_CERT_AUTHORITY_INVALID` | mkcert CA not trusted by browser | Run `mkcert -install`; restart browser |
| Firefox still warns after install | Snap Firefox uses separate NSS store | Import root CA into NSS (see §5) |
| Flutter rejects certificate | Device does not trust mkcert CA | Install the root CA on the emulator/device; for Android emulator, push the CA to the system trust store |
| Traefik logs TLS error | Cert/key path mismatch or wrong filename | Verify `infrastructure/certs/local.crt` and `local.key` exist and match the dynamic config paths |
| Mixed-content blocking | App on HTTPS, API on HTTP | Ensure API base URL uses `https://api.chtohochu.test` |

## 11. Non-Goals

- No self-signed certificates without a trusted CA (they cause browser warnings and
  complicate mobile testing).
- No disabling TLS verification in any client or CI environment.
- No use of production certificates locally. Production certs are managed in the
  deployment environment (see [`environments.md`](./environments.md)).
