<?php
/**
 * PhantomEye Auto-Merge Handler
 * 
 * Purpose: Automatically merge orphaned video chunks when the process terminates
 * Usage: Called by phantomeye.sh on SIGINT/SIGTERM or can be run standalone
 * 
 * Features:
 * - Detects incomplete video sessions in uploads directory
 * - Merges chunks in correct order with integrity checks
 * - Handles missing or corrupted chunks gracefully
 * - Provides detailed logging for debugging
 * - Cleans up temporary files after successful merge
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/merge_handler.log');

class AutoMergeHandler {
    private $uploadDir;
    private $finalDir;
    private $logFile;
    private $stats = [
        'sessions_found' => 0,
        'sessions_merged' => 0,
        'total_chunks' => 0,
        'total_bytes' => 0,
        'errors' => []
    ];

    public function __construct($baseDir = null) {
        if ($baseDir === null) {
            // Check if we're in saved_videos directory
            if (basename(dirname(__FILE__)) === 'saved_videos' || basename(__DIR__) === 'saved_videos') {
                $baseDir = __DIR__;
            } else {
                $baseDir = __DIR__ . '/saved_videos';
            }
        }

        $this->uploadDir = rtrim($baseDir, '/') . '/uploads/';
        $this->finalDir = rtrim($baseDir, '/') . '/final/';
        $this->logFile = rtrim($baseDir, '/') . '/auto_merge.log';

        $this->ensureDirectories();
    }

    /**
     * Ensure required directories exist with proper permissions
     */
    private function ensureDirectories(): void {
        foreach ([$this->uploadDir, $this->finalDir] as $dir) {
            if (!is_dir($dir)) {
                if (!mkdir($dir, 0777, true)) {
                    $this->logError("Failed to create directory: $dir");
                    throw new Exception("Cannot create directory: $dir");
                }
                chmod($dir, 0777);
            }
        }
    }

    /**
     * Main entry point - scan and merge all orphaned sessions
     */
    public function mergeAll(): array {
        $this->log("=== AUTO-MERGE STARTED ===");
        $this->log("Upload directory: {$this->uploadDir}");
        $this->log("Final directory: {$this->finalDir}");

        $sessions = $this->detectSessions();
        
        if (empty($sessions)) {
            $this->log("No orphaned sessions found");
            return $this->stats;
        }

        $this->stats['sessions_found'] = count($sessions);
        $this->log("Found {$this->stats['sessions_found']} session(s) to merge");

        foreach ($sessions as $sessionId => $chunks) {
            try {
                $this->mergeSession($sessionId, $chunks);
                $this->stats['sessions_merged']++;
            } catch (Exception $e) {
                $this->stats['errors'][] = "Session $sessionId: " . $e->getMessage();
                $this->logError("Failed to merge session $sessionId: " . $e->getMessage());
            }
        }

        $this->log("=== AUTO-MERGE COMPLETED ===");
        $this->log("Sessions merged: {$this->stats['sessions_merged']}/{$this->stats['sessions_found']}");
        $this->log("Total chunks: {$this->stats['total_chunks']}");
        $this->log("Total bytes: " . $this->formatBytes($this->stats['total_bytes']));

        return $this->stats;
    }

    /**
     * Detect all sessions with chunks in uploads directory
     */
    private function detectSessions(): array {
        $sessions = [];
        $files = glob($this->uploadDir . '*.part*');

        if ($files === false || empty($files)) {
            return [];
        }

        foreach ($files as $file) {
            // Extract session ID from filename (format: sessionId.part0)
            if (preg_match('/^(.+)\.part(\d+)$/', basename($file), $matches)) {
                $sessionId = $matches[1];
                $chunkIndex = (int)$matches[2];

                if (!isset($sessions[$sessionId])) {
                    $sessions[$sessionId] = [];
                }

                $sessions[$sessionId][$chunkIndex] = $file;
            }
        }

        // Sort chunks within each session
        foreach ($sessions as $sessionId => &$chunks) {
            ksort($chunks);
        }

        return $sessions;
    }

    /**
     * Merge a single session's chunks into final video
     */
    private function mergeSession(string $sessionId, array $chunks): void {
        $this->log("--- Merging session: $sessionId ---");
        $this->log("Chunks found: " . count($chunks));

        $ext = $this->detectExtension($sessionId);
        $this->log("Extension: $ext");

        $missingChunks = $this->detectMissingChunks($chunks);
        if (!empty($missingChunks)) {
            $this->log("WARNING: Missing chunks: " . implode(', ', $missingChunks));
        }

        $timestamp = time();
        $finalFilename = "recording_{$sessionId}_{$timestamp}.{$ext}";
        $finalPath = $this->finalDir . $finalFilename;

        $mergeResult = $this->performMerge($chunks, $finalPath);

        if (!$mergeResult['success']) {
            throw new Exception("Merge failed: " . $mergeResult['error']);
        }

        $this->stats['total_chunks'] += $mergeResult['chunks_merged'];
        $this->stats['total_bytes'] += $mergeResult['total_bytes'];

        $this->cleanup($sessionId, $chunks);

        $this->writeCompletionLog($finalFilename, $mergeResult);

        $this->log("Successfully merged: $finalFilename ({$this->formatBytes($mergeResult['total_bytes'])})");
    }

    /**
     * Detect file extension from metadata file or infer from first chunk
     */
    private function detectExtension(string $sessionId): string {
        $extFile = $this->uploadDir . $sessionId . '.ext';
        
        if (file_exists($extFile)) {
            $ext = trim(file_get_contents($extFile));
            if (!empty($ext)) {
                return strtolower($ext);
            }
        }

        // Default to webm if no metadata
        return 'webm';
    }

    /**
     * Detect missing chunks in sequence
     */
    private function detectMissingChunks(array $chunks): array {
        $indices = array_keys($chunks);
        $missing = [];

        if (empty($indices)) {
            return $missing;
        }

        $min = min($indices);
        $max = max($indices);

        for ($i = $min; $i <= $max; $i++) {
            if (!isset($chunks[$i])) {
                $missing[] = $i;
            }
        }

        return $missing;
    }

    /**
     * Perform binary-safe merge with integrity checks
     */
    private function performMerge(array $chunks, string $outputPath): array {
        $result = [
            'success' => false,
            'chunks_merged' => 0,
            'total_bytes' => 0,
            'error' => null
        ];

        $fp = fopen($outputPath, 'wb');
        if ($fp === false) {
            $result['error'] = "Cannot open output file: $outputPath";
            return $result;
        }

        foreach ($chunks as $index => $chunkPath) {
            if (!file_exists($chunkPath)) {
                $this->log("WARNING: Chunk $index not found, skipping");
                continue;
            }

            $chunkSize = filesize($chunkPath);
            if ($chunkSize === 0) {
                $this->log("WARNING: Chunk $index is empty, skipping");
                unlink($chunkPath); // Remove empty chunks
                continue;
            }

            $chunkData = file_get_contents($chunkPath);
            if ($chunkData === false) {
                $this->log("WARNING: Cannot read chunk $index, skipping");
                continue;
            }

            if (strlen($chunkData) !== $chunkSize) {
                $this->log("WARNING: Chunk $index size mismatch (expected $chunkSize, got " . strlen($chunkData) . ")");
            }

            $bytesWritten = fwrite($fp, $chunkData, strlen($chunkData));
            if ($bytesWritten === false || $bytesWritten !== strlen($chunkData)) {
                $this->log("ERROR: Failed to write chunk $index (wrote $bytesWritten/" . strlen($chunkData) . " bytes)");
                continue;
            }

            $result['chunks_merged']++;
            $result['total_bytes'] += $bytesWritten;
        }

        fclose($fp);

        if (!file_exists($outputPath) || filesize($outputPath) === 0) {
            $result['error'] = "Merge produced empty or missing file";
            return $result;
        }

        chmod($outputPath, 0644);
        $result['success'] = true;

        return $result;
    }

    /**
     * Clean up temporary files after successful merge
     */
    private function cleanup(string $sessionId, array $chunks): void {
        // Remove chunk files
        foreach ($chunks as $chunkPath) {
            if (file_exists($chunkPath)) {
                unlink($chunkPath);
            }
        }

        // Remove extension metadata
        $extFile = $this->uploadDir . $sessionId . '.ext';
        if (file_exists($extFile)) {
            unlink($extFile);
        }

        $this->log("Cleanup completed for session: $sessionId");
    }

    /**
     * Write completion log entry
     */
    private function writeCompletionLog(string $filename, array $mergeResult): void {
        $logEntry = sprintf(
            "Video completed: %s | Size: %s | Chunks: %d | Time: %s\n",
            $filename,
            $this->formatBytes($mergeResult['total_bytes']),
            $mergeResult['chunks_merged'],
            date('Y-m-d H:i:s')
        );

        file_put_contents(dirname($this->uploadDir) . '/Log_finish.log', $logEntry, FILE_APPEND | LOCK_EX);
    }

    /**
     * Log message to file
     */
    private function log(string $message): void {
        $timestamp = date('Y-m-d H:i:s');
        $logEntry = "[$timestamp] $message" . PHP_EOL;
        file_put_contents($this->logFile, $logEntry, FILE_APPEND | LOCK_EX);
    }

    /**
     * Log error message
     */
    private function logError(string $message): void {
        $this->log("ERROR: $message");
        error_log($message);
    }

    /**
     * Format bytes to human-readable size
     */
    private function formatBytes(int $bytes): string {
        if ($bytes >= 1073741824) {
            return number_format($bytes / 1073741824, 2) . ' GB';
        } elseif ($bytes >= 1048576) {
            return number_format($bytes / 1048576, 2) . ' MB';
        } elseif ($bytes >= 1024) {
            return number_format($bytes / 1024, 2) . ' KB';
        } else {
            return $bytes . ' bytes';
        }
    }
}

if (php_sapi_name() === 'cli') {
    // CLI execution
    $baseDir = $argv[1] ?? null;
    $handler = new AutoMergeHandler($baseDir);
    $stats = $handler->mergeAll();
    
    echo "\n=== AUTO-MERGE RESULTS ===\n";
    echo "Sessions found: {$stats['sessions_found']}\n";
    echo "Sessions merged: {$stats['sessions_merged']}\n";
    echo "Total chunks: {$stats['total_chunks']}\n";
    echo "Total size: " . (new AutoMergeHandler())->formatBytes($stats['total_bytes']) . "\n";
    
    if (!empty($stats['errors'])) {
        echo "\nERRORS:\n";
        foreach ($stats['errors'] as $error) {
            echo "  - $error\n";
        }
    }
    
    exit(empty($stats['errors']) ? 0 : 1);
} else {
    // Web execution (for manual trigger)
    header('Content-Type: application/json');
    try {
        $handler = new AutoMergeHandler();
        $stats = $handler->mergeAll();
        echo json_encode(['status' => 'success', 'stats' => $stats]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}
