# ADR-010: Local HTTPS with mkcert

## Status

Accepted

## Context

Several ЧтоХочу features require HTTPS to behave correctly, and the local environment
uses `*.chtohochu.test` domains (not `localhost`), so the browser's `localhost` HTTPS
exemption does not apply:

- **OAuth redirects.** VK and Yandex OAuth providers require HTTPS redirect URIs.
  `http://api.chtohochu.test/...` is rejected or behaves unpredictably.
- **Secure cookies.** Sanctum stateful domains and CSRF tokens use `Secure` cookies,
  which browsers only send over HTTPS. Without HTTPS, the public-web cabinet auth
  flow does not work correctly.
- **WebSockets (WSS).** Browsers block insecure `ws://` connections from `https://`
  pages (mixed content). The realtime client must use `wss://`, which requires TLS
  on `ws.chtohochu.test`.
- **Service workers.** Service workers only register on HTTPS or `localhost`. Since
  local uses `*.chtohochu.test`, HTTPS is required for any PWA-capable web app.
- **Mixed-content rules.** Serving web apps over HTTPS while calling an HTTP API
  triggers mixed-content blocking. Everything must be HTTPS.

The local environment therefore needs TLS certificates for `*.chtohochu.test` that
are trusted by the local browser and OS, without per-host browser warnings and
without disabling TLS verification in client code.

## Decision

Use **mkcert** to create a locally-trusted certificate authority (CA) and issue a
wildcard certificate for `*.chtohochu.test`.

`mkcert -install` creates a local root CA and installs it into the system and browser
trust stores. `mkcert "chtohochu.test" "*.chtohochu.test" localhost 127.0.0.1 ::1`
issues a certificate trusted by the local machine. The certificate and key are placed
in the Traefik certs volume and referenced by Traefik's TLS configuration (ADR-009).

The mkcert root CA is machine-local and must not be committed or shared. The
certificate private key is git-ignored.

## Consequences

**Positive**

- **No browser warnings.** Because the mkcert root CA is trusted locally, the
  wildcard certificate is accepted without per-host exceptions. The developer
  experience is seamless.
- **Real OAuth flows locally.** HTTPS redirect URIs work, so VK/Yandex OAuth can be
  tested end-to-end locally.
- **Secure cookies and WSS work locally.** Sanctum stateful domains, CSRF tokens,
  and `wss://` WebSockets behave as in production.
- **No client TLS bypass.** Client code (Flutter, web) does not need
  `allowInsecure` / `badCertificateCallback` hacks, so local testing exercises the
  real TLS path.
- **Single wildcard cert.** One certificate covers all `*.chtohochu.test` hosts; new
  subdomains do not require re-issuance.

**Negative**

- **Per-machine CA setup.** Each developer runs `mkcert -install` once. This is a
  one-time setup cost documented in the local-https guide.
- **Mobile emulator trust.** Mobile emulators/devices do not automatically trust the
  mkcert CA; the root CA must be installed on the emulator/device for Flutter to
  accept the certificate. This is documented and is a one-time setup per emulator.
- **Not portable.** The certificate and CA are machine-local and must not be
  committed. New developers generate their own. This is correct (secrets are never
  committed) but means `make certs` is part of onboarding.

## Alternatives considered

### Self-signed certificates (without a trusted CA)

Generate a self-signed certificate directly and accept the browser warning per host.

- **Strengths:** no tooling installation; works immediately.
- **Rejected because** every browser visit produces a warning that must be bypassed
  per host, which is noisy and hides real certificate problems. Mobile clients
  (Flutter) reject self-signed certs by default and require per-client TLS bypass
  code, which is unsafe and masks real issues. Per-host exceptions do not scale to
  seven local domains. The developer experience is poor and encourages disabling TLS
  verification, which is exactly the habit we want to avoid.

### Disabled TLS verification

Run the API and WebSocket over plain HTTP and disable TLS verification in clients.

- **Strengths:** no certificates to manage.
- **Rejected because** it makes local behaviour diverge from production (where TLS is
  mandatory), hiding HTTPS-dependent bugs until staging. It also requires client code
  to disable TLS verification, which is unsafe, must never ship, and is easy to
  forget to re-enable. AGENTS.md §12 mandates HTTPS everywhere. Disabling TLS
  verification locally violates the spirit of that rule and trains developers to
  ignore certificate errors. mkcert gives real TLS locally with no client bypass.
