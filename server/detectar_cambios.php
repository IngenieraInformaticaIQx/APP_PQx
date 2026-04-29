<?php

$baseDir = '/home/admin/domains/planificacionquirurgica.com/public_html/profesional/3D/';
$snapshotFile = __DIR__ . '/snapshots_casos.json';
$tokensFile = __DIR__ . '/tokens_fcm.json';
$projectId = 'pqxpush-77004';
$keyFile = '/home/admin/firebase_private/pqxpush-9ca9f91523ac.json';

$subcarpetas = [
    'archivos' => 'documento',
    'documentacion' => 'documento',
    'Biomodelo' => 'modelo3d',
    'Placas' => 'modelo3d',
    'Tornillos' => 'modelo3d',
];

function estadisticasRecursivas(string $dir): array
{
    $count = 0;
    $lastModified = 0;
    $items = array_filter(scandir($dir), fn($f) => $f !== '.' && $f !== '..');

    foreach ($items as $item) {
        $path = $dir . '/' . $item;
        if (is_dir($path)) {
            $sub = estadisticasRecursivas($path);
            $count += $sub['count'];
            $lastModified = max($lastModified, $sub['last_modified']);
        } else {
            $count++;
            $mtime = filemtime($path) ?: 0;
            $lastModified = max($lastModified, $mtime);
        }
    }

    return ['count' => $count, 'last_modified' => $lastModified];
}

$snapshot = file_exists($snapshotFile)
    ? (json_decode(file_get_contents($snapshotFile), true) ?? [])
    : [];

$cambios = [];
$grupos = array_filter(scandir($baseDir), fn($d) => $d !== '.' && $d !== '..' && is_dir($baseDir . $d));

foreach ($grupos as $grupo) {
    $grupoPath = $baseDir . $grupo . '/';
    $casos = array_filter(scandir($grupoPath), fn($d) => $d !== '.' && $d !== '..' && is_dir($grupoPath . $d));

    foreach ($casos as $caso) {
        $casoPath = $grupoPath . $caso . '/';

        foreach ($subcarpetas as $carpeta => $label) {
            $carpetaPath = $casoPath . $carpeta . '/';
            if (!is_dir($carpetaPath)) {
                continue;
            }

            $stats = estadisticasRecursivas($carpetaPath);
            $key = $grupo . '/' . $caso . '/' . $carpeta;

            if (!isset($snapshot[$key])) {
                $snapshot[$key] = $stats;
                continue;
            }

            $prev = $snapshot[$key];
            $prevCount = $prev['count'] ?? 0;
            $prevModified = $prev['last_modified'] ?? 0;

            if (
                $stats['count'] > $prevCount ||
                $stats['last_modified'] > $prevModified
            ) {
                $cambios[] = ['grupo' => $grupo, 'caso' => $caso, 'tipo' => $label];
                $snapshot[$key] = $stats;
            }
        }
    }
}

file_put_contents($snapshotFile, json_encode($snapshot, JSON_PRETTY_PRINT));
if (empty($cambios)) {
    exit(0);
}

function base64url_encode(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

$keyData = json_decode(file_get_contents($keyFile), true);
$now = time();

$header = base64url_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
$claim = base64url_encode(json_encode([
    'iss' => $keyData['client_email'],
    'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
    'aud' => 'https://oauth2.googleapis.com/token',
    'iat' => $now,
    'exp' => $now + 3600,
]));

$signatureInput = $header . '.' . $claim;
openssl_sign($signatureInput, $signature, $keyData['private_key'], 'sha256WithRSAEncryption');
$jwt = $signatureInput . '.' . base64url_encode($signature);

$ch = curl_init('https://oauth2.googleapis.com/token');
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POSTFIELDS => http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt,
    ]),
]);
$tokenResponse = json_decode(curl_exec($ch), true);
curl_close($ch);

if (!isset($tokenResponse['access_token'])) {
    file_put_contents(
        __DIR__ . '/detectar_cambios_error.log',
        date('Y-m-d H:i:s') . ' ERROR token: ' . json_encode($tokenResponse) . "\n",
        FILE_APPEND
    );
    exit(1);
}

$accessToken = $tokenResponse['access_token'];
$tokensPorGrupo = file_exists($tokensFile)
    ? (json_decode(file_get_contents($tokensFile), true) ?? [])
    : [];

if (empty($tokensPorGrupo)) {
    exit(0);
}

foreach ($cambios as $cambio) {
    $grupo = $cambio['grupo'];
    $tokens = $tokensPorGrupo[$grupo] ?? [];
    if (empty($tokens) || !is_array($tokens)) {
        continue;
    }

    $nombreCaso = $cambio['caso'];
    $title = $cambio['tipo'] === 'modelo3d'
        ? 'Hay nuevos modelos 3D en tu caso'
        : 'Hay un documento nuevo en tu caso';

    foreach ($tokens as $deviceToken) {
        $message = [
            'message' => [
                'token' => $deviceToken,
                'notification' => ['title' => $title, 'body' => $nombreCaso],
                'android' => [
                    'priority' => 'high',
                    'notification' => [
                        'channel_id' => 'pqx_channel',
                    ],
                ],
                'apns' => [
                    'headers' => ['apns-priority' => '10'],
                    'payload' => ['aps' => ['content-available' => 1, 'sound' => 'default']],
                ],
            ],
        ];

        $ch = curl_init("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send");
        curl_setopt_array($ch, [
            CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $accessToken, 'Content-Type: application/json'],
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($message),
            CURLOPT_RETURNTRANSFER => true,
        ]);
        $result = curl_exec($ch);
        curl_close($ch);

        file_put_contents(
            __DIR__ . '/detectar_cambios.log',
            date('Y-m-d H:i:s') . " [{$grupo}/{$nombreCaso}] {$title}: {$result}\n",
            FILE_APPEND
        );
    }
}
