<?php
// Alias for the single-order view. Same missing ownership check as orders.php.
// Kept as a separate path because older links and the scenarios doc use it.
$_GET['id'] = isset($_GET['id']) ? (int) $_GET['id'] : 0;
require __DIR__ . '/orders.php';
