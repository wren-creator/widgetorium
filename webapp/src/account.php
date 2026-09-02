<?php
require_once __DIR__ . '/lib/helpers.php';

// "Current user" is resolved purely from the WIDGET_SESSID cookie. Forge a
// token for another user id (vuln 13) and this page shows their account.
$u = wdg_require_login();

wdg_header('Account');
?>
<h1>Your account</h1>
<table class="kv">
  <tr><th>User ID</th><td><?= (int) $u['id'] ?></td></tr>
  <tr><th>Username</th><td><?= htmlspecialchars($u['username']) ?></td></tr>
  <tr><th>Email</th><td><?= htmlspecialchars($u['email']) ?></td></tr>
  <tr><th>Role</th><td><?= htmlspecialchars($u['role']) ?></td></tr>
  <tr><th>Session token</th><td><code><?= htmlspecialchars($_COOKIE[WDG_COOKIE] ?? '') ?></code></td></tr>
</table>
<p>Your <a href="/orders.php">order history</a>.</p>
<?php
wdg_footer();
