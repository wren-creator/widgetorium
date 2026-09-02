#!/usr/bin/env bash
# vuln 9: plant a .git directory under /var/www/html/admin with a live secret
# in the first commit and a "fix" in the second. The working tree ends up
# clean; the secret is only recoverable from history (git log -p, git-dumper).
#
# Runs at image build time. Fixed author/committer dates keep the commit
# hashes identical across rebuilds.
set -euo pipefail

ADMIN_DIR=/var/www/html/admin
cd "$ADMIN_DIR"

export GIT_AUTHOR_NAME="Dev Ops"
export GIT_AUTHOR_EMAIL="dev@widgetorium.local"
export GIT_COMMITTER_NAME="Dev Ops"
export GIT_COMMITTER_EMAIL="dev@widgetorium.local"

git init -q
git config user.name  "Dev Ops"
git config user.email "dev@widgetorium.local"
git config commit.gpgsign false

# --- commit 1: API key committed in cleartext -----------------------------
export GIT_AUTHOR_DATE="2024-11-02T09:14:00 +0000"
export GIT_COMMITTER_DATE="2024-11-02T09:14:00 +0000"
cat > config.php <<'PHP'
<?php
// Admin panel configuration.
define('WIDGETORIUM_API_KEY', 'wdg_live_sk_7f3c9a1e42b84d06b1e5c2aa9d770f18');
define('DB_DSN', 'mysql:host=db;dbname=widgetorium');
define('DB_USER', 'widgetorium');
define('DB_PASS', 'widgetorium');
PHP
git add config.php
git commit -q -m "add admin api integration + db config"

# --- commit 2: key "moved to an environment variable" (still in history) ---
export GIT_AUTHOR_DATE="2024-11-04T15:40:00 +0000"
export GIT_COMMITTER_DATE="2024-11-04T15:40:00 +0000"
cat > config.php <<'PHP'
<?php
// Admin panel configuration.
// API key moved out of source control, see WIDGETORIUM_API_KEY in the env.
define('WIDGETORIUM_API_KEY', getenv('WIDGETORIUM_API_KEY') ?: '');
define('DB_DSN', 'mysql:host=' . (getenv('DB_HOST') ?: 'db') . ';dbname=' . (getenv('DB_NAME') ?: 'widgetorium'));
define('DB_USER', getenv('DB_USER') ?: 'widgetorium');
define('DB_PASS', getenv('DB_PASS') ?: 'widgetorium');
PHP
git add config.php
git commit -q -m "move api key to environment variable"

echo "[plant-git] planted $ADMIN_DIR/.git"
git --no-pager log --oneline
