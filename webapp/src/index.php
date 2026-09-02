<?php
require_once __DIR__ . '/lib/helpers.php';

// Catalogue listing. This page is clean; the interesting query is on search.php.
$rows = wdg_query("SELECT id, name, description, price, stock FROM products ORDER BY id")->fetchAll();

wdg_header('Widgets');
?>
<h1>Every widget we stock</h1>
<p class="lede">Fasteners, brackets, trims and tidies. Nothing you want, everything you need.</p>

<div class="grid">
<?php foreach ($rows as $p): ?>
  <article class="card">
    <a href="/product.php?id=<?= (int) $p['id'] ?>"><?= htmlspecialchars($p['name']) ?></a>
    <p class="desc"><?= htmlspecialchars($p['description']) ?></p>
    <p class="price"><?= wdg_money($p['price']) ?> &middot; <?= (int) $p['stock'] ?> in stock</p>
  </article>
<?php endforeach; ?>
</div>
<?php
wdg_footer();
