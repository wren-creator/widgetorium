<?php
require __DIR__ . '/_guard.php';

// vuln 3, SINK side. For each product, the stored name is concatenated into a
// new query against stock_ledger. A product saved (via products.php) with a
// name like
//
//   x' UNION SELECT GROUP_CONCAT(username,0x3a,password_hash) FROM users-- -
//
// sits harmless in the catalogue and storefront, then fires here when the
// report runs. The result is printed in the "on hand" column.
//
// Gated on SECOND_ORDER_SINK so an instructor can disable just this path.

$sinkEnabled = wdg_config()['second_order_sink'];

$products = wdg_query("SELECT id, name FROM products ORDER BY id")->fetchAll();

$report = [];
foreach ($products as $p) {
    if ($sinkEnabled) {
        // vulnerable: stored value straight into SQL
        $sql = "SELECT COALESCE(SUM(delta),0) AS on_hand
                  FROM stock_ledger WHERE label = '" . $p['name'] . "'";
    } else {
        // safe variant for the "toggle off" case
        $sql = "SELECT COALESCE(SUM(delta),0) AS on_hand FROM stock_ledger WHERE label = "
             . wdg_db()->quote($p['name']);
    }
    try {
        $on = wdg_db()->query($sql)->fetch();
        $onHand = $on['on_hand'];
    } catch (PDOException $e) {
        $onHand = '(error) ' . $e->getMessage();
    }
    $report[] = ['id' => $p['id'], 'name' => $p['name'], 'on_hand' => $onHand];
}

wdg_header('Admin · inventory report');
?>
<h1>Inventory report</h1>
<p class="lede">Net on-hand per product, from the stock ledger.</p>
<table class="list">
  <thead><tr><th>ID</th><th>Product</th><th>On hand</th></tr></thead>
  <tbody>
  <?php foreach ($report as $r): ?>
    <tr>
      <td><?= (int) $r['id'] ?></td>
      <td><?= htmlspecialchars($r['name']) ?></td>
      <td><?= htmlspecialchars((string) $r['on_hand']) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
<?php
wdg_footer();
