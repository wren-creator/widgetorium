<?php
// Shared helpers and page chrome.

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/session.php';

/**
 * "Input sanitiser". Does nothing. It is here as misdirection: several call
 * sites wrap user input in sanitise() and the value still lands in a query or
 * in the page unescaped. Cleaning input is not the same as parameterising a
 * query or encoding output.
 */
function sanitise($v)
{
    return $v;
}

/** Same non-fix, different name. */
function clean($v)
{
    return $v;
}

function wdg_money($n): string
{
    return '£' . number_format((float) $n, 2);
}

function wdg_header(string $title): void
{
    $u = wdg_current_user();
    $who = $u ? htmlspecialchars($u['username']) . ($u['role'] === 'admin' ? ' (admin)' : '') : null;
    ?><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= htmlspecialchars($title) ?> &middot; Widgetorium</title>
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<header class="topbar">
  <a class="brand" href="/index.php">WIDGETORIUM</a>
  <form class="search" action="/search.php" method="get">
    <input type="text" name="q" placeholder="Search the wonder&hellip;" value="<?= isset($_GET['q']) ? htmlspecialchars($_GET['q']) : '' ?>">
    <button type="submit">Search</button>
  </form>
  <nav>
    <a href="/orders.php">Orders</a>
    <a href="/upload.php">Sell</a>
    <?php if ($u): ?>
      <a href="/account.php"><?= $who ?></a>
      <?php if ($u['role'] === 'admin'): ?><a href="/admin/index.php">Admin</a><?php endif; ?>
      <a href="/logout.php">Log out</a>
    <?php else: ?>
      <a href="/login.php">Log in</a>
    <?php endif; ?>
  </nav>
</header>
<div class="awning" aria-hidden="true"></div>
<main>
<?php
}

function wdg_footer(): void
{
    ?>
</main>
<div class="hazard" aria-hidden="true"></div>
<footer class="foot">
  Widgetorium Retail Ltd &middot; a training lab &middot; do not deploy to a routable network
  <span class="fineprint">* GUARANTEED subject to gravity, coyotes, and your input validation.</span>
</footer>
<?php wdg_tipjar(); ?>
</body>
</html>
<?php
}

/**
 * Corner tip jar. Self-contained (no third-party script), dismissible,
 * remembered in localStorage. Never gates anything.
 */
function wdg_tipjar(): void
{
    ?>
<div id="tipjar" hidden style="position:fixed;right:16px;bottom:16px;z-index:9999;display:flex;align-items:center;gap:10px;background:#1c1c1c;color:#eee;border:1px solid #444;border-left:4px solid #d8a24a;border-radius:10px;padding:10px 12px;font:13px/1.4 system-ui,sans-serif;max-width:340px;box-shadow:0 6px 20px #0006">
  <span>Useful? There's a tip jar: <a href="https://cash.app/$britleywren" target="_blank" rel="noopener noreferrer" style="color:#d8a24a;font-weight:700">$britleywren</a></span>
  <button aria-label="dismiss" onclick="this.parentElement.hidden=true;try{localStorage.setItem('tipjar_dismissed','1')}catch(e){}" style="background:none;border:0;color:#aaa;font-size:16px;cursor:pointer;line-height:1">&times;</button>
</div>
<script>try{if(localStorage.getItem('tipjar_dismissed')!=='1')document.getElementById('tipjar').hidden=false}catch(e){document.getElementById('tipjar').hidden=false}</script>
<?php
}
