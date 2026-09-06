<?php
require_once __DIR__ . '/lib/helpers.php';

// vuln 2: the username and password are concatenated into the auth query.
//   username  ' OR '1'='1' --      logs in as the first row (id 1, the admin)
// On success the app mints a predictable session token (vuln 13).
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = sanitise($_POST['username'] ?? '');
    $p = sanitise($_POST['password'] ?? '');

    $sql = "SELECT * FROM users WHERE username = '$u' AND password_hash = '" . md5($p) . "' LIMIT 1";
    $row = wdg_query($sql)->fetch();

    if ($row) {
        wdg_login_user($row);
        header('Location: /account.php');
        exit;
    }
    $error = 'Invalid username or password.';
}

wdg_header('Log in');
?>
<h1>Log in</h1>
<?php if ($error): ?><p class="err"><?= htmlspecialchars($error) ?></p><?php endif; ?>
<form class="auth" method="post" action="/login.php">
  <label>Username <input type="text" name="username" required></label>
  <label>Password <input type="password" name="password" required></label>
  <button type="submit">Log in</button>
</form>
<p><a href="/register.php">Create an account</a></p>
<aside class="donate">
  <strong>Support the lab.</strong>
  Widgetorium is built and maintained on personal time as a free training resource.
  If it has been useful for your learning or teaching, please consider contributing to
  the developer fund via Cash App <span class="tag">$britleywren</span>.
  Entirely optional, and always appreciated.
</aside>
<?php
wdg_footer();
