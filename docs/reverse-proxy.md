# Reverse Proxy

The default deployment publishes port `6868` directly on the LAN. This is the
simplest and most reliable option for TrueNAS, whose own web UI usually occupies
ports 80 and 443.

If you need HTTPS, a hostname, or an authenticating gateway, put a reverse proxy
in front of the app.

## Requirements

PancakeSlicer uses Server-Sent Events (SSE) for slice progress and printer
status, and it accepts model uploads up to 512 MiB by default. A proxy must:

- Disable response buffering for streaming endpoints.
- Allow request bodies up to at least 512 MiB.
- Use a long response-header timeout, because slicing can take many minutes.
- Preserve the `Authorization` header if you use a bearer token.
- Forward `X-Forwarded-For` if you want accurate client IPs.

Set `PANCAKE_TRUSTED_PROXIES` in `.env` to the proxy's source CIDR. For a proxy
container on the default Docker bridge network, `172.16.0.0/12` is a common
starting point; narrow it to the actual proxy address when possible.

## Authentication

`PANCAKE_BEARER_TOKEN` protects mutation endpoints only. It does not make reads
private. If the app is reachable from the Internet, add authentication at the
proxy (Basic Auth, OIDC, mTLS, or a VPN) in addition to the bearer token.

## nginx

```nginx
server {
    listen 443 ssl;
    server_name slicer.example.com;

    ssl_certificate     /etc/ssl/certs/slicer.crt;
    ssl_certificate_key /etc/ssl/private/slicer.key;

    client_max_body_size 512m;

    location / {
        proxy_pass http://127.0.0.1:6868;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Authorization $http_authorization;

        # SSE: stream progress without buffering.
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 40m;
        proxy_send_timeout 40m;
    }
}
```

If the proxy is in a Docker container alongside the app, use the app's service
name or container address instead of `127.0.0.1`.

## Caddy

This is adapted from the upstream `deploy/caddy/Caddyfile`:

```caddyfile
slicer.example.com {
    request_body {
        max_size 512MiB
    }
    reverse_proxy pancakeslicer:6868 {
        # Stream SSE unbuffered.
        flush_interval -1
        transport http {
            response_header_timeout 40m
        }
    }
}
```

Caddy normally obtains a public certificate on ports 80/443. On TrueNAS those
ports are usually taken, so run Caddy elsewhere, bind it to alternate ports with
router forwarding, or use a DNS challenge and internal TLS.

## Traefik

Use a buffering-disabled middleware for the app and set the forwarding response
timeout to a large value:

```yaml
http:
  middlewares:
    pancakeslicer-buffering:
      buffering:
        maxRequestBodyBytes: 536870912
        memRequestBodyBytes: 1048576
  serversTransports:
    pancakeslicer:
      forwardingTimeouts:
        responseHeaderTimeout: 40m
```

Attach `pancakeslicer-buffering` to the router and use the
`pancakeslicer` server transport.

## Bearer token with a proxy

If the proxy injects the token, configure it to send an `Authorization: Bearer`
header to the app. Keep the token value in the proxy's secret store, not in a
tracked file.

## Testing

After configuring the proxy:

```bash
curl -I https://slicer.example.com/
curl -fsS https://slicer.example.com/api/healthz
```

Then start a slice and confirm progress updates arrive continuously rather than
in one burst at the end. If updates stall, buffering is still enabled somewhere.

Check the app logs and the proxy logs for `413 Request Entity Too Large`,
`504 Gateway Timeout`, or SSE disconnects.
