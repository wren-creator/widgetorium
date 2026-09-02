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
</body>
</html>
<?php
}
