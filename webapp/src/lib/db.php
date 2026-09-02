<?php
// Database access for Widgetorium.
//
// vuln 14: on a query failure the handler prints the failing SQL, the driver
// message, and a backtrace straight into the response when VERBOSE_ERRORS=1.
// That is exactly what leaks table and column names to someone probing the
// SQL-injection points.

function wdg_config(): array
{
    static $cfg = null;
    if ($cfg === null) {
        $cfg = require __DIR__ . '/../config.php';
    }
    return $cfg;
}

function wdg_db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }
    $c = wdg_config()['db'];
    $dsn = "mysql:host={$c['host']};dbname={$c['name']};charset=utf8mb4";

    // Retry briefly so the first request after `up` does not race the DB.
    $lastErr = null;
    for ($i = 0; $i < 30; $i++) {
        try {
            $pdo = new PDO($dsn, $c['user'], $c['pass'], [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => true,
            ]);
            return $pdo;
        } catch (PDOException $e) {
            $lastErr = $e;
            sleep(1);
        }
    }
    http_response_code(500);
    echo "database unavailable: " . htmlspecialchars($lastErr ? $lastErr->getMessage() : 'unknown');
    exit;
}

/**
 * Run a raw SQL string and return the statement.
 * Intentionally does no escaping. Several pages build $sql by concatenation.
 */
function wdg_query(string $sql): PDOStatement
{
    try {
        return wdg_db()->query($sql);
    } catch (PDOException $e) {
        wdg_sql_error($sql, $e);
    }
}

/** Same, for prepared/parameterised statements. */
function wdg_prepare(string $sql): PDOStatement
{
    try {
        return wdg_db()->prepare($sql);
    } catch (PDOException $e) {
        wdg_sql_error($sql, $e);
    }
}

function wdg_sql_error(string $sql, PDOException $e): void
{
    http_response_code(500);
    if (wdg_config()['verbose_errors']) {
        echo "<pre style=\"background:#fee;border:1px solid #c00;padding:12px;white-space:pre-wrap\">";
        echo "SQL ERROR\n";
        echo "  query : " . htmlspecialchars($sql) . "\n";
        echo "  driver: " . htmlspecialchars($e->getMessage()) . "\n\n";
        echo htmlspecialchars((new Exception())->getTraceAsString());
        echo "</pre>";
    } else {
        echo "<p>Sorry, something went wrong processing your request.</p>";
    }
    exit;
}
