<?php
require __DIR__ . '/_guard.php';

// vuln 3, WRITE side. The product name is stored through a *parameterised*
// statement, so quotes and SQL metacharacters survive untouched and no
// scanner sees anything happen here. The payload sits inert in products.name
// until admin/inventory_report.php concatenates it into a fresh query.
$saved = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name  = sanitise($_POST['name'] ?? '');          // no-op wrapper, misdirection
    $desc  = $_POST['description'] ?? '';
    $price = (float) ($_POST['price'] ?? 0);
    $stock = (int) ($_POST['stock'] ?? 0);
    $id    = (int) ($_POST['id'] ?? 0);

    if ($id > 0) {
        $st = wdg_prepare(
            "UPDATE products SET name = :n, description = :d, price = :p, stock = :s WHERE id = :id"
        );
        $st->execute([':n' => $name, ':d' => $desc, ':p' => $price, ':s' => $stock, ':id' => $id]);
        $saved = "updated #$id";
    } else {
        $st = wdg_prepare(
            "INSERT INTO products (name, description, price, stock, owner_user_id)
             VALUES (:n, :d, :p, :s, :o)"
        );
        $st->execute([
            ':n' => $name, ':d' => $desc, ':p' => $price, ':s' => $stock,
            ':o' => $GLOBALS['wdg_admin']['id'],
        ]);
        $saved = "created #" . wdg_db()->lastInsertId();
    }
}

$rows = wdg_query("SELECT id, name, price, stock FROM products ORDER BY id DESC")->fetchAll();

wdg_header('Admin · products');
?>
<h1>Manage products</h1>
<?php if ($saved): ?><p class="ok"><?= htmlspecialchars($saved) ?></p><?php endif; ?>

<form class="admin-form" method="post" action="/admin/products.php">
  <input type="hidden" name="id" value="0">
  <label>Name <input type="text" name="name" size="60" required></label>
  <label>Description <input type="text" name="description" size="60"></label>
  <label>Price <input type="text" name="price" value="0.00"></label>
  <label>Stock <input type="text" name="stock" value="0"></label>
  <button type="submit">Add product</button>
</form>

<table class="list">
  <thead><tr><th>ID</th><th>Name</th><th>Price</th><th>Stock</th></tr></thead>
  <tbody>
  <?php foreach ($rows as $p): ?>
    <tr>
      <td><?= (int) $p['id'] ?></td>
      <td><?= htmlspecialchars($p['name']) ?></td>
      <td><?= wdg_money($p['price']) ?></td>
      <td><?= (int) $p['stock'] ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
<?php
wdg_footer();
