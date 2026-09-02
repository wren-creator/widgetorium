<?php
// vuln 13: predictable session tokens.
//
// The auth identity is the WIDGET_SESSID cookie, NOT PHP's native session.
// When WEAK_SESSIONS=1 the token is:
//
//     dechex(time()) . str_pad(dechex(user_id), 4, '0', STR_PAD_LEFT)
//
// so anyone who sees one token, or just knows roughly when a user logged in,
// can enumerate a few hundred candidates for a target user_id and take over
// the session. With WEAK_SESSIONS=0 a random token is issued instead.

require_once __DIR__ . '/db.php';

const WDG_COOKIE = 'WIDGET_SESSID';

function wdg_mint_token(int $userId): string
{
    if (wdg_config()['weak_sessions']) {
        return dechex(time()) . str_pad(dechex($userId), 4, '0', STR_PAD_LEFT);
    }
    return bin2hex(random_bytes(24));
}

function wdg_login_user(array $user): void
{
    $token = wdg_mint_token((int) $user['id']);
    $st = wdg_prepare("INSERT INTO sessions (token, user_id) VALUES (:t, :u)");
    $st->execute([':t' => $token, ':u' => $user['id']]);
    setcookie(WDG_COOKIE, $token, [
        'expires'  => 0,
        'path'     => '/',
        'httponly' => false,
        'secure'   => false,
        'samesite' => 'Lax',
    ]);
    $_COOKIE[WDG_COOKIE] = $token;
}

function wdg_logout(): void
{
    $token = $_COOKIE[WDG_COOKIE] ?? '';
    if ($token !== '') {
        $st = wdg_prepare("DELETE FROM sessions WHERE token = :t");
        $st->execute([':t' => $token]);
    }
    setcookie(WDG_COOKIE, '', ['expires' => time() - 3600, 'path' => '/']);
    unset($_COOKIE[WDG_COOKIE]);
}

function wdg_current_user(): ?array
{
    $token = $_COOKIE[WDG_COOKIE] ?? '';
    if ($token === '') {
        return null;
    }
    $st = wdg_prepare(
        "SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = :t"
    );
    $st->execute([':t' => $token]);
    $row = $st->fetch();
    return $row ?: null;
}

function wdg_require_login(): array
{
    $u = wdg_current_user();
    if (!$u) {
        header('Location: /login.php');
        exit;
    }
    return $u;
}
