<?php
require __DIR__ . '/_guard.php';

$count = wdg_query("SELECT COUNT(*) c FROM products")->fetch()['c'];

wdg_header('Admin');
?>
<h1>Admin dashboard</h1>
<p>Signed in as <strong><?= htmlspecialchars($GLOBALS['wdg_admin']['username']) ?></strong>.</p>
<ul class="list">
  <li><a href="/admin/products.php">Manage products</a> (<?= (int) $count ?> in catalogue)</li>
  <li><a href="/admin/inventory_report.php">Inventory report</a></li>
</ul>
<?php
wdg_footer();
