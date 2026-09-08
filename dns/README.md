# dns/ — the lab nameserver

BIND9, authoritative-only, no recursion. Published on `127.0.0.1:5300`
(TCP and UDP): port 53 belongs to the host resolver, and 5353 is taken by
mDNS/Bonjour on macOS, so the lab uses 5300 and you point your tools at it.

| File | Purpose |
|---|---|
| `named.conf` | options plus the two zone stanzas; `corp` has `allow-transfer { any; }` (bug 20) |
| `zones/db.corp.widgetorium.lab` | the internal zone: live vhost names, stale `10.10.x.x` records, TXT/SPF/DMARC, a wildcard |
| `zones/db.widgetorium.lab` | the public face: apex, `www`, `mail`, and an `NS` breadcrumb delegating `corp` |
| `entrypoint.sh` | copies the read-only configs to a writable path, applies `OPEN_AXFR`, runs `named -g` |

## Querying it

```bash
dig @127.0.0.1 -p 5300 corp.widgetorium.lab SOA
dig @127.0.0.1 -p 5300 corp.widgetorium.lab AXFR        # bug 20: full zone dump
dig @127.0.0.1 -p 5300 widgetorium.lab AXFR             # refused, as it should be
dnsrecon -n 127.0.0.1 -p 5300 -d corp.widgetorium.lab -t axfr
```

## Reaching the vhosts from a browser

The names resolve to `127.0.0.1` only through this server. To browse them add:

```
127.0.0.1  corp.widgetorium.lab www.corp.widgetorium.lab admin.corp.widgetorium.lab dev.corp.widgetorium.lab staging.corp.widgetorium.lab
```

to `/etc/hosts`, or point `curl` with `--resolve` / `-H "Host: ..."`.

## Toggle

`OPEN_AXFR=1` (default) leaves the `corp` zone transfer wide open. `OPEN_AXFR=0`
locks it, for a graded exercise where that bug is off the table.
