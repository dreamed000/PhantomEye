<?php

// Enable error logging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', 'location_errors.log');

/**
 * Sanitize and validate coordinate
 */
function validate_coordinate($value, $min, $max) {
    $value = filter_var($value, FILTER_VALIDATE_FLOAT);
    if ($value === false || $value < $min || $value > $max) {
        return null;
    }
    return $value;
}

/**
 * Sanitize numeric value
 */
function sanitize_numeric($value) {
    $value = filter_var($value, FILTER_VALIDATE_FLOAT);
    return ($value !== false) ? $value : null;
}

$session_id = substr(md5(uniqid(mt_rand(), true)), 0, 10);

$lat = validate_coordinate($_POST['lat'] ?? null, -90, 90);
$lon = validate_coordinate($_POST['lon'] ?? null, -180, 180);
$acc = sanitize_numeric($_POST['acc'] ?? null);
$alt = sanitize_numeric($_POST['alt'] ?? null);
$altAcc = sanitize_numeric($_POST['altAcc'] ?? null);
$heading = sanitize_numeric($_POST['heading'] ?? null);
$speed = sanitize_numeric($_POST['speed'] ?? null);
$time = htmlspecialchars($_POST['time'] ?? date('Y-m-d H:i:s'), ENT_QUOTES, 'UTF-8');

if ($lat === null || $lon === null) {
    error_log("Invalid location data received");
    http_response_code(400);
    die(json_encode(['status' => 'error', 'message' => 'Invalid coordinates']));
}

$data = "Latitude: " . number_format($lat, 6) . "\n"
      . "Longitude: " . number_format($lon, 6) . "\n"
      . "Accuracy: " . ($acc !== null ? number_format($acc, 2) . "m" : "N/A") . "\n"
      . "Altitude: " . ($alt !== null ? number_format($alt, 2) . "m" : "N/A") . "\n"
      . "Altitude Accuracy: " . ($altAcc !== null ? number_format($altAcc, 2) . "m" : "N/A") . "\n"
      . "Heading: " . ($heading !== null ? number_format($heading, 2) . "°" : "N/A") . "\n"
      . "Speed: " . ($speed !== null ? number_format($speed, 2) . "m/s" : "N/A") . "\n"
      . "Timestamp: $time\n"
      . "Google Maps: https://maps.google.com/?q=$lat,$lon\n"
      . "Session: $session_id\n"
      . "----------------------------------------\n";

$timestamp = date('YmdHis');
$filename = "location_{$session_id}_{$timestamp}.txt";

$locationDir = 'saved_locations';
if (!is_dir($locationDir)) {
    if (!mkdir($locationDir, 0755, true)) {
        error_log("Failed to create saved_locations directory");
        http_response_code(500);
        die(json_encode(['status' => 'error', 'message' => 'Server configuration error']));
    }
}

$filepath = $locationDir . '/' . $filename;
if (file_put_contents($filepath, $data, LOCK_EX) === false) {
    error_log("Failed to save location data to: $filepath");
    http_response_code(500);
    die(json_encode(['status' => 'error', 'message' => 'Failed to save location']));
}

if (file_put_contents('current_location.txt', $data, FILE_APPEND | LOCK_EX) === false) {
    error_log("Failed to append to current_location.txt");
}

if (file_put_contents('LocationLog.log', $data, FILE_APPEND | LOCK_EX) === false) {
    error_log("Failed to append to LocationLog.log");
}

http_response_code(200);
echo json_encode([
    'status' => 'success',
    'message' => 'Location received successfully',
    'filename' => $filename,
    'coordinates' => [
        'latitude' => $lat,
        'longitude' => $lon,
        'accuracy' => $acc
    ]
]);
?>
