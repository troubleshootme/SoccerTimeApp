<?php
// Allow CORS for local development
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

header('Content-Type: application/json');

// Directory where session files are stored
$sessionDir = __DIR__ . '/sessions';

// Ensure the sessions directory exists
if (!is_dir($sessionDir)) {
    if (!mkdir($sessionDir, 0777, true)) {
        echo json_encode(['error' => 'Failed to create sessions directory']);
        exit;
    }
}

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Log the request for debugging
file_put_contents('php_debug.log', "Request received: " . print_r($_SERVER, true) . "\n", FILE_APPEND);
file_put_contents('php_debug.log', "Request body: " . file_get_contents('php://input') . "\n", FILE_APPEND);

// Read the request body
$input = file_get_contents('php://input');
if (empty($input)) {
    file_put_contents('php_debug.log', "Error: No input provided\n", FILE_APPEND);
    echo json_encode(['error' => 'No input provided']);
    exit;
}

$data = json_decode($input, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    file_put_contents('php_debug.log', "Error: Invalid JSON input: " . json_last_error_msg() . "\n", FILE_APPEND);
    echo json_encode(['error' => 'Invalid JSON input: ' . json_last_error_msg()]);
    exit;
}

if (!isset($data['action'])) {
    file_put_contents('php_debug.log', "Error: Invalid action\n", FILE_APPEND);
    echo json_encode(['error' => 'Invalid action']);
    exit;
}

$action = $data['action'];
$password = isset($data['password']) ? $data['password'] : null;
$sessionFile = $sessionDir . '/' . $password . '.json';

// Clean up old session files (older than 60 days)
$files = glob($sessionDir . '/*.json');
foreach ($files as $file) {
    if (filemtime($file) < time() - 60 * 24 * 60 * 60) {
        unlink($file);
    }
}

switch ($action) {
    case 'check':
        if (!$password) {
            file_put_contents('php_debug.log', "Error: Password required for check action\n", FILE_APPEND);
            echo json_encode(['error' => 'Password required']);
            exit;
        }
        $exists = file_exists($sessionFile);
        file_put_contents('php_debug.log', "Check action - Password: $password, Exists: " . ($exists ? 'true' : 'false') . "\n", FILE_APPEND);
        echo json_encode(['exists' => $exists]);
        break;

    case 'load':
        if (!$password) {
            file_put_contents('php_debug.log', "Error: Password required for load action\n", FILE_APPEND);
            echo json_encode(['error' => 'Password required']);
            exit;
        }
        if (!file_exists($sessionFile)) {
            file_put_contents('php_debug.log', "Error: Session not found for password: $password\n", FILE_APPEND);
            echo json_encode(['error' => 'Session not found']);
            exit;
        }
        $content = file_get_contents($sessionFile);
        file_put_contents('php_debug.log', "Load action - Password: $password, Content: $content\n", FILE_APPEND);
        echo $content;
        break;

    case 'save':
        if (!$password || !isset($data['data'])) {
            file_put_contents('php_debug.log', "Error: Password and data required for save action\n", FILE_APPEND);
            echo json_encode(['error' => 'Password and data required']);
            exit;
        }
        $result = file_put_contents($sessionFile, json_encode($data['data']));
        if ($result === false) {
            file_put_contents('php_debug.log', "Error: Failed to save session for password: $password\n", FILE_APPEND);
            echo json_encode(['error' => 'Failed to save session']);
            exit;
        }
        file_put_contents('php_debug.log', "Save action - Password: $password, Data saved successfully\n", FILE_APPEND);
        echo json_encode(['success' => true]);
        break;

    default:
        file_put_contents('php_debug.log', "Error: Invalid action: $action\n", FILE_APPEND);
        echo json_encode(['error' => 'Invalid action']);
        break;
}
?>