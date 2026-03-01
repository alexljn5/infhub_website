<?php
// infhub_lounge_auth.php
// Proxy authentication to The Lounge

header('Content-Type: application/json');

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
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

// The Lounge server details
$lounge_host = '213.197.11.201';
$lounge_port = '9000';
$lounge_url = "http://$lounge_host:$lounge_port/api/v4/auth/login";

// Prepare The Lounge authentication request
$lounge_data = json_encode([
    'username' => $username,
    'password' => $password
]);

$ch = curl_init($lounge_url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $lounge_data);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($http_code === 200) {
    $lounge_response = json_decode($response, true);
    
    // Successful authentication with The Lounge
    echo json_encode([
        'valid' => true,
        'token' => $lounge_response['token'] ?? null,
        'user' => [
            'username' => $username
        ]
    ]);
} else {
    // Failed authentication
    http_response_code(401);
    echo json_encode(['valid' => false, 'error' => 'Invalid credentials']);
}
exit;
?>
