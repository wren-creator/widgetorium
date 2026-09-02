<?php
require_once __DIR__ . '/lib/helpers.php';

// Catalogue listing. This page is clean; the interesting query is on search.php.
$rows = wdg_query("SELECT id, name, description, price, stock FROM products ORDER BY id")->fetchAll();

// The golden ticket: one product, drawn fresh each load.
$ticket = $rows ? $rows[array_rand($rows)] : null;

wdg_header('Widgets');
?>
<h1>Every widget we make</h1>
<p class="lede">Fasteners, brackets, trims and tidies. Nothing you want, everything you need.</p>

<?php if ($ticket): ?>
<section class="ticket">
  <svg class="star" width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round">
    <path d="M12 2l2.9 6.2 6.6.8-4.9 4.5 1.3 6.7L12 17.8 6 20.7l1.3-6.7L2.4 9l6.6-.8z"/>
  </svg>
  <div class="thumb"><?= htmlspecialchars(substr($ticket['name'], 0, 1)) ?></div>
  <div class="body">
    <div class="kicker">The Golden Ticket &middot; today only</div>
    <div class="name"><a href="/product.php?id=<?= (int) $ticket['id'] ?>"><?= htmlspecialchars($ticket['name']) ?></a></div>
    <div class="meta"><?= wdg_money($ticket['price']) ?> &middot; <?= (int) $ticket['stock'] ?> in stock &middot; <?= htmlspecialchars($ticket['description']) ?></div>
    <a class="go" href="/product.php?id=<?= (int) $ticket['id'] ?>">Claim it</a>
  </div>
</section>
<?php endif; ?>

<div class="grid">
<?php foreach ($rows as $p): ?>
  <article class="card">
    <span class="guarantee">Guaranteed*</span>
    <a href="/product.php?id=<?= (int) $p['id'] ?>"><?= htmlspecialchars($p['name']) ?></a>
    <p class="desc"><?= htmlspecialchars($p['description']) ?></p>
    <p class="price"><?= wdg_money($p['price']) ?> &middot; <?= (int) $p['stock'] ?> in stock</p>
  </article>
<?php endforeach; ?>
</div>
<?php
wdg_footer();
