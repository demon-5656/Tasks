<?php
header('Content-Type: application/json');
header('Cache-Control: no-store');
$node = gethostname();
$database = null;
try {
    if (getenv('DB_HOST')) {
        mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
        $db = new mysqli(getenv('DB_HOST'), getenv('DB_USER'), getenv('DB_PASSWORD'), getenv('DB_NAME'));
        $database = (int) $db->query('SELECT 1 AS ok')->fetch_assoc()['ok'] === 1;
        $db->close();
    }
    echo json_encode(['status' => 'ok', 'node' => $node, 'php' => PHP_VERSION, 'database' => $database]);
} catch (Throwable $e) {
    http_response_code(503);
    echo json_encode(['status' => 'unhealthy', 'node' => $node, 'database' => false]);
}
