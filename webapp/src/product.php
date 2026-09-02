<?php
require_once __DIR__ . '/lib/helpers.php';

$id = isset($_GET['id']) ? (int) $_GET['id'] : 0;

$st = wdg_prepare("SELECT * FROM products WHERE id = :id");
$st->execute([':id' => $id]);
$p = $st->fetch();

if (!$p) {
    http_response_code(404);
    wdg_header('Not found');
    echo '<h1>No such widget</h1>';
    wdg_footer();
    exit;
}

$rst = wdg_prepare("SELECT author, body, created_at FROM reviews WHERE product_id = :id ORDER BY id DESC");
$rst->execute([':id' => $id]);
$reviews = $rst->fetchAll();

wdg_header($p['name']);
?>
<article class="product">
  <h1><?= htmlspecialchars($p['name']) ?></h1>
  <p class="price"><?= wdg_money($p['price']) ?></p>
  <p class="stock"><?= (int) $p['stock'] ?> in stock</p>
  <p><?= htmlspecialchars($p['description']) ?></p>
</article>

<section class="reviews">
  <h2>Reviews</h2>
  <?php if (!$reviews): ?>
    <p>No reviews yet.</p>
  <?php else: ?>
    <?php foreach ($reviews as $r): ?>
      <div class="review">
        <p class="meta"><strong><?= htmlspecialchars($r['author']) ?></strong>
          &middot; <?= htmlspecialchars($r['created_at']) ?></p>
        <!-- vuln 11: stored review body rendered without output encoding -->
        <p class="body"><?= $r['body'] ?></p>
      </div>
    <?php endforeach; ?>
  <?php endif; ?>

  <form class="review-form" action="/review.php" method="post">
    <input type="hidden" name="product_id" value="<?= (int) $p['id'] ?>">
    <label>Name <input type="text" name="author" required></label>
    <label>Review <textarea name="body" required></textarea></label>
    <button type="submit">Post review</button>
  </form>
</section>
<?php
wdg_footer();
