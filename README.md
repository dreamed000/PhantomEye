# PhantomEye V4.0

![PhantomEye Banner](https://img.shields.io/badge/PhantomEye-V4.0-red)
![Platform](https://img.shields.io/badge/Platform-Termux%20%7C%20Kali%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-blue)
![PHP](https://img.shields.io/badge/PHP-7.4%2B-purple)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Fully%20Tested-brightgreen)

## 📋 Table of Contents
- [Overview](#overview)
- [Features](#-features)
- [Legal Disclaimer](#-legal-disclaimer)
- [System Requirements](#-system-requirements)
- [Installation Guide](#-installation-guide)
- [Quick Start](#-quick-start)
- [File Structure](#-file-structure)
- [Usage Guide](#-usage-guide)
- [Tunnel Services Comparison](#-tunnel-services-comparison)
- [Template Details](#-template-details)
- [Data Captured](#-data-captured)
- [Technical Architecture](#-technical-architecture)
- [Testing Results](#-testing-results)
- [Troubleshooting](#-troubleshooting)
- [Frequently Asked Questions](#-frequently-asked-questions)
- [Security Best Practices](#-security-best-practices)
- [Ethical Guidelines](#-ethical-guidelines)
- [Updates & Changelog](#-updates--changelog)
- [Contributing](#-contributing)
- [Credits & Acknowledgments](#-credits--acknowledgments)
- [Support](#-support)
- [License](#-license)

## Overview
PhantomEye V4.0 is an advanced, multi-platform penetration testing tool designed for authorized security assessments and educational purposes. It provides comprehensive data capture capabilities including real-time location tracking, camera access, and video recording through carefully crafted social engineering scenarios.

## ✨ Features

### Core Capabilities
- **Multi-Platform Support**: Full compatibility with Termux, Kali Linux, Windows, Linux, and macOS
- **Multiple Tunnel Options**: Ngrok, Cloudflare Tunnel, LocalTunnel, and Local PHP Server
- **Comprehensive Data Capture**: IP addresses, geolocation, video recordings
- **Smart Video Processing**: Chunk-based recording with automatic merging
- **Advanced Location Tracking**: Dual-mode location capture with retry mechanism

### Technical Features
- **Auto-Dependency Installation**: Automatic detection and installation of missing dependencies
- **Process Management**: Proper cleanup and termination of background services
- **Error Resilience**: Comprehensive error handling with fallback mechanisms
- **Smart Logging**: Filtered logging system to remove noise and debug information
- **Security Hardened**: Input validation, XSS prevention, and file type restrictions

### User Experience
- **Interactive CLI**: User-friendly command-line interface with color-coded output
- **Real-time Monitoring**: Live updates on captured data
- **Automatic File Organization**: Structured directory system for captured data
- **Template System**: Pre-built professional-looking templates for various scenarios

## ⚠️ Legal Disclaimer

**IMPORTANT - READ BEFORE USE**

### Legal Notice
This software is intended **SOLELY** for:
- Authorized penetration testing with written permission
- Security research in controlled environments
- Educational purposes in academic settings
- Testing your own systems that you own or have explicit permission to test

### Strictly Prohibited
- Unauthorized testing of any system
- Malicious activities or cyber attacks
- Violation of privacy laws
- Any illegal activities

### Liability
The developers assume **NO LIABILITY** for any misuse of this software. Users are solely responsible for ensuring they have proper authorization before using this tool. By using this software, you acknowledge that you understand and agree to these terms.

**ALWAYS OBTAIN PROPER AUTHORIZATION BEFORE CONDUCTING ANY SECURITY TESTING**

## 🔧 System Requirements

### Minimum Requirements
- **Processor**: 1 GHz or faster
- **RAM**: 512 MB minimum, 1 GB recommended
- **Storage**: 100 MB free space
- **Internet**: Active connection for tunneling services

### Software Requirements
#### For Termux (Android)
- Termux app (from F-Droid)
- Android 7.0 or higher
- Storage permission granted

#### For Kali Linux
- Kali Linux 2023.x or newer
- Root/sudo access
- Working package manager

#### For Windows
- Windows 10/11 with WSL2 (recommended)
- OR native PHP installation
- Administrator privileges

#### For macOS
- macOS 10.15 (Catalina) or newer
- Homebrew package manager
- Terminal access

### Network Requirements
- Open ports: 3333 (local server)
- Outbound connections allowed
- No aggressive firewall blocking

## 📥 Installation Guide

### Termux Installation
```bash
# Update and upgrade packages
pkg update -y && pkg upgrade -y

# Install essential tools
pkg install -y git php curl wget unzip termux-api

# Clone repository
git clone https://github.com/dreamed000/PhantomEye.git

# Navigate to directory
cd PhantomEye_v4

# Set permissions
chmod +x phantomeye.sh

# Grant storage permission (optional)
termux-setup-storage
