<?php
require_once __DIR__ . '/../lib/helpers.php';

header('Content-Type: application/json');

// vuln 4: price / quantity update endpoint.
//   - authz: any logged-in user may call it. There is NO check that the
//     product's owner_user_id matches the caller, and no admin-role check
//     (IDOR-style: a regular customer edits items that are not theirs).
//   - injection: id / price / qty are concatenated into the UPDATE. The price
//     field is a straight expression context, so
//       price=(SELECT LOAD_FILE('/var/lib/mysql-files/secret.txt'))
//     reads a file from the DB container (FILE priv + secure_file_priv="").
//
// Accepts form-encoded or JSON body: {id, price, qty}.

$u = wdg_current_user();
if (!$u) {
    http_response_code(401);
    echo json_encode(['error' => 'log in first']);
    exit;
}

$body = $_POST;
if (!$body) {
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true) ?: [];
}

$id    = $body['id']    ?? null;
$price = $body['price'] ?? null;
$qty   = $body['qty']   ?? null;

if ($id === null || ($price === null && $qty === null)) {
    http_response_code(400);
    echo json_encode(['error' => 'need id and at least one of price, qty']);
    exit;
}

$sets = [];
if ($price !== null) { $sets[] = "price = " . sanitise($price); }
if ($qty   !== null) { $sets[] = "stock = " . sanitise($qty); }

$sql = "UPDATE products SET " . implode(', ', $sets) . " WHERE id = " . sanitise($id);
wdg_query($sql);

// echo the row back so a trainee can see LOAD_FILE output land in `price`
$row = wdg_query("SELECT id, name, price, stock, owner_user_id FROM products WHERE id = " . sanitise($id))->fetch();

echo json_encode([
    'ok'      => true,
    'updated' => $row,
    'as_user' => ['id' => (int) $u['id'], 'role' => $u['role']],
], JSON_PRETTY_PRINT);
