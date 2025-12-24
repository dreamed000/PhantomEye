<!-- Shield Badges for visual appeal and immediate project status recognition -->
<div align="center">

# 🔐 PhantomEye

**Browser Security Awareness & Web API Demonstration Platform**

*An educational, multi-platform framework designed exclusively for authorized security research, controlled lab demonstrations, and cybersecurity education.*

[![GitHub License](https://img.shields.io/badge/License-MIT-important)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-success)](#contributing)
[![Maintenance](https://img.shields.io/badge/Maintained-Actively%20Developed-informational)](#)
[![Platform](https://img.shields.io/badge/Platform-Termux%20|%20Kali%20|%20Linux%20|%20macOS%20|%20WSL-blue)](#-system-requirements)

</div>

---

## 🚨 Critical Legal & Ethical Notice

> **⚠️ WARNING: STRICT LEGAL BOUNDARIES**
>
> **PhantomEye is developed and distributed solely for legitimate, authorized purposes within educational and lab contexts.**

### 🛡️ Authorized Use Cases
You may use this tool **ONLY** if you fall into one of the following categories:
*   **Security Professionals & Penetration Testers** conducting assessments **with explicit, written permission**.
*   **Security Researchers** analyzing systems they own or have explicit authority to test.
*   **Educational Institutions & Students** using the tool in controlled lab environments for learning cybersecurity principles.
*   **System Administrators** testing the security of their own infrastructure.

### ⛔ Strictly Prohibited Activities
Unauthorized use of this software is a criminal offense in most jurisdictions. Prohibited activities include, but are not limited to:
*   Testing systems without the **owner's explicit consent**.
*   Accessing or modifying data you are not authorized to.
*   Disrupting services or causing harm.
*   Violating individual privacy.
*   Any activity intended to act maliciously or unlawfully.

### 📜 Full Disclaimer
**THE DEVELOPERS AND CONTRIBUTORS OF PHANTOMEYE V4.0 ASSUME NO LIABILITY AND ARE NOT RESPONSIBLE FOR ANY MISUSE OR DAMAGE CAUSED BY THIS PROGRAM.** By using this software, you agree to comply with all applicable laws.  

> ⚠️ Note: This project does NOT bypass browser security, does NOT access devices without consent, and does NOT exploit vulnerabilities. All interactions rely strictly on standard browser permission prompts.

---

## 📋 Table of Contents

*   [✨ Overview](#-overview)
*   [🎯 Core Features](#-core-features)
*   [⚙️ System Requirements](#️-system-requirements)
*   [🚀 Quick Installation](#-quick-installation)
*   [📖 Comprehensive Usage Guide](#-comprehensive-usage-guide)
*   [🏗️ Architecture & Data Flow](#️-architecture--data-flow)
*   [🤝 Contributing Guidelines](#-contributing-guidelines)
*   [❓ Frequently Asked Questions (FAQ)](#-frequently-asked-questions-faq)
*   [📜 License](#-license)

---

## ✨ Overview

PhantomEye is a professional **educational security lab framework**.  
It demonstrates how browsers request permissions and how web APIs handle media and location access in a **controlled lab environment**.  

**Primary Goals:**
1. **Education:** Serve as a teaching tool for cybersecurity courses on client-side security and browser permissions.  
2. **Research:** Enable security professionals to test and understand system behavior **ethically**.  
3. **Awareness:** Promote user privacy and consent awareness in web applications.

---

## 🎯 Core Features

| Feature | Description | Purpose |
| :--- | :--- | :--- |
| **🌐 Multi-Tunnel Support** | Generates lab testing links via Cloudflare, Ngrok, LocalTunnel, or local PHP server. | Allows easy testing in controlled environments. |
| **📝 User Awareness Simulation Templates** | Pre-built educational pages (Greeting, Meeting, YouTube Demo) that request browser permissions. | Demonstrates how users interact with permission prompts responsibly. |
| **📍 Geolocation Demonstration** | Shows multiple techniques (GPS, network-based, IP fallback) for learning purposes. | Helps learners understand location APIs without invading privacy. |
| **📹 Browser Permission Demonstration** | Demonstrates how browsers request camera / media access, strictly with consent. | Educates users about media permission prompts. |
| **⚡ Smart Data Handling** | Automatic file organization, structured logs, and lab-safe data handling. | Keeps test data organized for educational analysis. |

---

## ⚙️ System Requirements

### Recommended Hardware
*   **Processor:** 1.5 GHz dual-core (64-bit)
*   **RAM:** 2 GB minimum
*   **Storage:** 500 MB free space
*   **Network:** Stable internet connection for tunnel services

### Software Dependencies
The core script will attempt to install missing dependencies, but pre-installing these is recommended:

| Platform | Core Dependencies | Command |
| :--- | :--- | :--- |
| **Kali Linux / Debian** | `php`, `curl`, `wget`, `unzip` | `sudo apt install php curl wget unzip` |
| **Termux (Android)** | `php`, `curl`, `wget`, `unzip`, `termux-api` | `pkg install php curl wget unzip termux-api` |
| **macOS (via Homebrew)** | `php`, `curl`, `wget` | `brew install php curl wget` |

---

## 🚀 Quick Installation

### For Kali Linux / Most Linux Distributions
```bash
# Clone the repository
git clone https://github.com/dreamed000/PhantomEye.git
cd PhantomEye

# Make the script executable and run it
chmod +x phantomeye.sh
./phantomeye.sh


### For Termux
```bash
git clone https://github.com/dreamed000/PhantomEye.git
cd PhantomEye

# Make the script executable and run it
chmod +x phantomeye.sh
bash phantomeye.sh


## License
This project is licensed under the MIT License.


## Final Note
Education, ethics, and responsible practice come first.
This project demonstrates browser security, permission handling, and user-awareness best practices in a controlled lab environment.
