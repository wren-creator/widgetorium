<?php
require_once __DIR__ . '/lib/helpers.php';

// Ordinary account creation. Parameterised on the way in; passwords are stored
// as unsalted MD5 to match the seed data (that is its own weakness, used for
// the hash-cracking sub-exercise, not a headline bug).
$error = null;
$done  = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $u = trim($_POST['username'] ?? '');
    $e = trim($_POST['email'] ?? '');
    $p = $_POST['password'] ?? '';

    if ($u === '' || $e === '' || $p === '') {
        $error = 'All fields are required.';
    } else {
        try {
            $st = wdg_prepare(
                "INSERT INTO users (username, email, password_hash, role) VALUES (:u, :e, :h, 'customer')"
            );
            $st->execute([':u' => $u, ':e' => $e, ':h' => md5($p)]);
            $done = true;
        } catch (PDOException $ex) {
            $error = 'That username is taken.';
        }
    }
}

wdg_header('Register');
?>
<h1>Create an account</h1>
<?php if ($done): ?>
  <p class="ok">Account created. <a href="/login.php">Log in</a>.</p>
<?php else: ?>
  <?php if ($error): ?><p class="err"><?= htmlspecialchars($error) ?></p><?php endif; ?>
  <form class="auth" method="post" action="/register.php">
    <label>Username <input type="text" name="username" required></label>
    <label>Email <input type="email" name="email" required></label>
    <label>Password <input type="password" name="password" required></label>
    <button type="submit">Register</button>
  </form>
<?php endif; ?>
<?php
wdg_footer();
