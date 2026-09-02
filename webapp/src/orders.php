<?php
require_once __DIR__ . '/lib/helpers.php';

// vuln 10: order history. If ?id= is supplied the page shows that order with
// no check that it belongs to the caller. Order ids are sequential from 1001,
// so they are trivially walkable. Without ?id= it lists the logged-in user's
// own orders (the "normal" path).
$u = wdg_current_user();

$viewId = isset($_GET['id']) ? (int) $_GET['id'] : 0;

if ($viewId > 0) {
    // no "AND customer_id = <session user>" anywhere here
    $st = wdg_prepare("SELECT * FROM orders WHERE id = :id");
    $st->execute([':id' => $viewId]);
    $order = $st->fetch();

    wdg_header('Order ' . $viewId);
    if (!$order) {
        echo '<h1>No such order</h1>';
        wdg_footer();
        exit;
    }
    $ist = wdg_prepare(
        "SELECT oi.qty, oi.unit_price, p.name
           FROM order_items oi JOIN products p ON p.id = oi.product_id
          WHERE oi.order_id = :id"
    );
    $ist->execute([':id' => $viewId]);
    $items = $ist->fetchAll();
    ?>
    <h1>Order #<?= (int) $order['id'] ?></h1>
    <p>Customer ID <?= (int) $order['customer_id'] ?> &middot;
       <?= htmlspecialchars($order['status']) ?> &middot;
       <?= htmlspecialchars($order['created_at']) ?></p>
    <table class="list">
      <thead><tr><th>Widget</th><th>Qty</th><th>Unit</th></tr></thead>
      <tbody>
      <?php foreach ($items as $it): ?>
        <tr><td><?= htmlspecialchars($it['name']) ?></td>
            <td><?= (int) $it['qty'] ?></td>
            <td><?= wdg_money($it['unit_price']) ?></td></tr>
      <?php endforeach; ?>
      </tbody>
    </table>
    <p class="price">Total <?= wdg_money($order['total']) ?></p>
    <?php
    wdg_footer();
    exit;
}

// list view
wdg_header('Orders');
if (!$u) {
    echo '<h1>Order history</h1><p>Please <a href="/login.php">log in</a> to see your orders.</p>';
    echo '<p>Or look up an order directly: <a href="/orders.php?id=1001">/orders.php?id=1001</a></p>';
    wdg_footer();
    exit;
}
$st = wdg_prepare("SELECT id, total, status, created_at FROM orders WHERE customer_id = :c ORDER BY id DESC");
$st->execute([':c' => $u['id']]);
$mine = $st->fetchAll();
?>
<h1>Your orders</h1>
<table class="list">
  <thead><tr><th>Order</th><th>Placed</th><th>Status</th><th>Total</th></tr></thead>
  <tbody>
  <?php foreach ($mine as $o): ?>
    <tr>
      <td><a href="/orders.php?id=<?= (int) $o['id'] ?>">#<?= (int) $o['id'] ?></a></td>
      <td><?= htmlspecialchars($o['created_at']) ?></td>
      <td><?= htmlspecialchars($o['status']) ?></td>
      <td><?= wdg_money($o['total']) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
<?php
wdg_footer();
