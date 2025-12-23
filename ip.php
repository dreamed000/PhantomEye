<?php

// Enable error logging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', 'ip_errors.log');

class IPLogger {
    private $file = 'ip.txt';
    
    /**
     * Get client IP address with proper validation
     * Check CF-Connecting-IP first for Cloudflare tunnels
     */
    public function getClientIP(): string {
        $ipSources = [
            'HTTP_CF_CONNECTING_IP',  // Cloudflare real client IP
            'HTTP_X_REAL_IP',         // Real IP header
            'HTTP_CLIENT_IP',
            'HTTP_X_FORWARDED_FOR',
            'HTTP_X_FORWARDED',
            'HTTP_X_CLUSTER_CLIENT_IP',
            'HTTP_FORWARDED_FOR',
            'HTTP_FORWARDED',
            'REMOTE_ADDR'
        ];
        
        foreach ($ipSources as $source) {
            if (!empty($_SERVER[$source])) {
                $ip = $_SERVER[$source];
                
                // Handle multiple IPs in X-Forwarded-For
                if (strpos($ip, ',') !== false) {
                    $ips = explode(',', $ip);
                    $ip = trim($ips[0]);
                }
                
                // Validate IP address (allow private IPs for local testing)
                $validated = filter_var($ip, FILTER_VALIDATE_IP);
                if ($validated !== false) {
                    // Skip Cloudflare IP ranges (if you want to log the real client)
                    if ($this->isCloudflareIP($ip)) {
                        continue;
                    }
                    return $validated;
                }
            }
        }
        
        return 'Unknown';
    }
    
    /**
     * Check if IP is from Cloudflare range (to skip and get real IP)
     */
    private function isCloudflareIP($ip): bool {
        // Common Cloudflare IP ranges (simplified check)
        $cfRanges = [
            '173.245.48.0/20',
            '103.21.244.0/22',
            '103.22.200.0/22',
            '103.31.4.0/22',
            '141.101.64.0/18',
            '108.162.192.0/18',
            '190.93.240.0/20',
            '188.114.96.0/20',
            '197.234.240.0/22',
            '198.41.128.0/17',
            '162.158.0.0/15',
            '104.16.0.0/13',
            '104.24.0.0/14',
            '172.64.0.0/13',
            '131.0.72.0/22'
        ];
        
        foreach ($cfRanges as $range) {
            if ($this->ipInRange($ip, $range)) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Check if IP is in CIDR range
     */
    private function ipInRange($ip, $range): bool {
        list($subnet, $mask) = explode('/', $range);
        $ip_long = ip2long($ip);
        $subnet_long = ip2long($subnet);
        $mask_long = -1 << (32 - $mask);
        $subnet_long &= $mask_long;
        return ($ip_long & $mask_long) == $subnet_long;
    }
    
    /**
     * Get user agent with sanitization
     */
    public function getUserAgent(): string {
        $ua = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
        return htmlspecialchars($ua, ENT_QUOTES, 'UTF-8');
    }
    
    /**
     * Log IP data with timestamp
     */
    public function logData(): void {
        $ip = $this->getClientIP();
        $userAgent = $this->getUserAgent();
        $timestamp = date('Y-m-d H:i:s');
        
        $logData = [
            "IP: " . $ip,
            "User-Agent: " . $userAgent,
            "Timestamp: " . $timestamp,
            "Referer: " . ($_SERVER['HTTP_REFERER'] ?? 'Direct'),
            "----------------------------------------"
        ];
        
        try {
            if (file_put_contents($this->file, implode(PHP_EOL, $logData) . PHP_EOL, FILE_APPEND | LOCK_EX) === false) {
                error_log("Failed to write to ip.txt");
            }
            
            // Also maintain a persistent log
            if (file_put_contents('ip_history.txt', implode(PHP_EOL, $logData) . PHP_EOL, FILE_APPEND | LOCK_EX) === false) {
                error_log("Failed to write to ip_history.txt");
            }
        } catch (Exception $e) {
            error_log("IP logging error: " . $e->getMessage());
        }
    }
}

// Execute the IP logging
$ipLogger = new IPLogger();
$ipLogger->logData();
?>
