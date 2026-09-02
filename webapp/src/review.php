<?php
require_once __DIR__ . '/lib/helpers.php';

// vuln 11 (stored XSS source): anyone can post a review, no auth, no login,
// no encoding on the way in. The body is stored verbatim and later rendered
// raw on product.php.
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: /index.php');
    exit;
}

$pid    = (int) ($_POST['product_id'] ?? 0);
$author = clean($_POST['author'] ?? 'anonymous');
$body   = clean($_POST['body'] ?? '');

$st = wdg_prepare("INSERT INTO reviews (product_id, author, body) VALUES (:p, :a, :b)");
$st->execute([':p' => $pid, ':a' => $author, ':b' => $body]);

header('Location: /product.php?id=' . $pid);
