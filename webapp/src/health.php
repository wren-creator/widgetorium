<?php
// Healthcheck target. Kept deliberately boring and dependency-free so the
// container reports healthy even if the DB is briefly down.
header('Content-Type: text/plain');
echo "ok\n";
