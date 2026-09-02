<?php
// Admin gate. Reached by:
//   - logging in as an admin (the SQLi auth bypass on login.php lands on the
//     first user row, which is the admin), or
//   - forging a predictable WIDGET_SESSID for user id 1 (vuln 13).
require_once __DIR__ . '/../lib/helpers.php';

$GLOBALS['wdg_admin'] = wdg_current_user();

// Weak check: role admin OR a low numeric user id. The id shortcut is itself
// a broken-access-control smell, but the intended path is role-based.
if (!$GLOBALS['wdg_admin'] ||
    !($GLOBALS['wdg_admin']['role'] === 'admin' || (int) $GLOBALS['wdg_admin']['id'] <= 1)) {
    http_response_code(403);
    wdg_header('Admin');
    echo '<h1>Forbidden</h1><p>Admin access only.</p>';
    wdg_footer();
    exit;
}
