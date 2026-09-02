<?php
require_once __DIR__ . '/lib/helpers.php';

// vuln 1: the search term is concatenated straight into a LIKE clause.
//   - three columns are selected, so UNION SELECT lines up cleanly
//   - a broken quote drops the raw SQL into the page (vuln 14)
//   - the term is echoed back without encoding (vuln 11, reflected XSS)
$q = isset($_GET['q']) ? sanitise($_GET['q']) : '';

$results = [];
if ($q !== '') {
    $sql = "SELECT id, name, price FROM products WHERE name LIKE '%$q%' ORDER BY name";
    $results = wdg_query($sql)->fetchAll();
}

wdg_header('Search');
?>
<h1>Search results</h1>

<?php if ($q !== ''): ?>
  <!-- vuln 11: reflected, unencoded -->
  <p class="lede">You searched for: <?= $q ?></p>
<?php endif; ?>

<?php if ($q === ''): ?>
  <p>Type something in the search box.</p>
<?php elseif (!$results): ?>
  <p>No widgets matched &ldquo;<?= $q ?>&rdquo;.</p>
<?php else: ?>
  <table class="list">
    <thead><tr><th>Widget</th><th>Price</th></tr></thead>
    <tbody>
    <?php foreach ($results as $r): ?>
      <tr>
        <td><a href="/product.php?id=<?= (int) $r['id'] ?>"><?= htmlspecialchars($r['name']) ?></a></td>
        <td><?= wdg_money($r['price']) ?></td>
      </tr>
    <?php endforeach; ?>
    </tbody>
  </table>
<?php endif; ?>
<?php
wdg_footer();
