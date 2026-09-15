<?php
// infhub_infcraft_irc_authentication.php

header('Content-Type: application/json');

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// Get POST data
$input = json_decode(file_get_contents('php://input'), true);
if (!$input || !isset($input['username'], $input['password'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing username or password']);
    exit;
}

$username = trim($input['username']);
$password = $input['password'];

// Database connection (uses environment variables from docker-compose)
$host = getenv('DB_HOST') ?: '127.0.0.1';
$db = getenv('DB_NAME') ?: 'infhub_database';
$user = getenv('DB_USER') ?: 'infhub_user';
$pass = getenv('DB_PASSWORD') ?: '';
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed']);
    exit;
}

// Fetch user
$stmt = $pdo->prepare("SELECT id, username, password_hash, role FROM users WHERE username = :username LIMIT 1");
$stmt->execute(['username' => $username]);
$userData = $stmt->fetch();

if (!$userData || !password_verify($password, $userData['password_hash'])) {
    // Invalid credentials
    http_response_code(401);
    echo json_encode(['valid' => false]);
    exit;
}

// Successful login
echo json_encode([
    'valid' => true,
    'user' => [
        'id' => $userData['id'],
        'username' => $userData['username'],
        'role' => $userData['role']
    ]
]);
exit;