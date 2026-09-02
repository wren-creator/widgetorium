<?php
require_once __DIR__ . '/lib/helpers.php';

// vuln 12: "add a product image" upload.
//   - no extension check, no MIME check, no size sanity beyond php.ini
//   - the client-supplied filename is used as-is, so ../ traversal works
//   - files land under the web root and PHP executes there (see
//     apache/dotfiles-allow.conf), so a .php upload is a webshell
$msg = null;
$link = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['image'])) {
    $f = $_FILES['image'];
    if ($f['error'] === UPLOAD_ERR_OK) {
        // The store lets the seller pick the stored filename. If they do not,
        // fall back to the browser-supplied name. PHP strips the path from
        // $_FILES['name'], but the 'filename' form field is taken as-is, so
        // ../ traversal works through it.
        $name = clean($_POST['filename'] ?? '');
        if ($name === '') {
            $name = clean($f['name']);
        }
        $dest = __DIR__ . '/uploads/' . $name;     // traversal reaches outside uploads/
        @mkdir(dirname($dest), 0777, true);
        if (move_uploaded_file($f['tmp_name'], $dest)) {
            $msg  = 'Uploaded as ' . $name;
            $link = '/uploads/' . $name;
        } else {
            $msg = 'Could not store the file.';
        }
    } else {
        $msg = 'Upload error code ' . (int) $f['error'];
    }
}

wdg_header('Sell a widget');
?>
<h1>List a widget for sale</h1>
<p>Upload a product photo. JPEG or PNG, ideally.</p>
<?php if ($msg): ?>
  <p class="ok"><?= htmlspecialchars($msg) ?>
    <?php if ($link): ?> &middot; <a href="<?= htmlspecialchars($link) ?>">view</a><?php endif; ?>
  </p>
<?php endif; ?>
<form method="post" enctype="multipart/form-data" action="/upload.php">
  <label>Image <input type="file" name="image" required></label>
  <label>Save as (optional) <input type="text" name="filename" placeholder="my-widget.jpg"></label>
  <button type="submit">Upload</button>
</form>

<h2>Recently uploaded</h2>
<ul class="list">
<?php
$dir = __DIR__ . '/uploads';
foreach (array_slice(array_diff(scandir($dir), ['.', '..', '.gitkeep']), 0, 25) as $file) {
    if (is_file("$dir/$file")) {
        echo '<li><a href="/uploads/' . htmlspecialchars($file) . '">' . htmlspecialchars($file) . '</a></li>';
    }
}
?>
</ul>
<?php
wdg_footer();
