<?php
declare(strict_types=1);

cors();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['success' => false, 'message' => 'Metodo no permitido']);
    exit;
}

$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
if ($auth === '' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $usuario = trim((string)($_POST['usuario'] ?? ''));
    $password = (string)($_POST['password'] ?? '');
    if ($usuario !== '' && $password !== '') {
        $auth = 'Basic ' . base64_encode($usuario . ':' . $password);
    }
}

if ($auth === '') {
    http_response_code(401);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['success' => false, 'message' => 'Falta usuario/password']);
    exit;
}

$response = proxy_get(
    'https://profesional.planificacionquirurgica.com/ocs/v2.php/cloud/user',
    [
        'Authorization: ' . $auth,
        'OCS-APIRequest: true',
    ]
);

http_response_code($response['status']);
header('Content-Type: ' . ($response['content_type'] ?: 'application/json; charset=utf-8'));
echo $response['body'];

function cors(): void
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Vary: Origin');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Authorization, OCS-APIRequest, Content-Type');
    header('Access-Control-Max-Age: 86400');
}

function proxy_get(string $url, array $headers): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_HEADER => true,
    ]);

    $raw = curl_exec($ch);
    if ($raw === false) {
        $message = curl_error($ch);
        curl_close($ch);
        return [
            'status' => 502,
            'content_type' => 'application/json; charset=utf-8',
            'body' => json_encode(['success' => false, 'message' => $message]),
        ];
    }

    $headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $contentType = (string) curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
    $body = substr($raw, $headerSize);
    curl_close($ch);

    return [
        'status' => $status > 0 ? $status : 502,
        'content_type' => $contentType,
        'body' => $body,
    ];
}
