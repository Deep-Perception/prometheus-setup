# Setup for Prometheus Software

## System Requirements:

1. Ubuntu 22.04 or 24.04 LTS Desktop. Note Arrow Lake systems need 24.04 LTS.
2. High core count CPU (i5 or better) to run 2 and 4 Hailo configurations. 
3. 1,2 or 4 Hailo-8 or Hailo-10H AI accelerators (Our scripts will install the kernel modules version, do not manually install the driver beforehand).
4. **Required to use setup script: Disable Secure Boot** in the BIOS or Hailo kernel module will not load.
5. Optional: Video sources consisting of any combination of ONVIF cameras, direct RTSP links and directly attached USB cameras. 1920x1080 10FPS sources preferred. Demo loop vidoes are included and may be used as an alternative or in combination with live sources.
6. System that supports VA-API h264 encode and decode (Most Intel and AMD integrated and discrete graphics cards supported).

## Initial Setup on clean Ubuntu 22.04 or 24.04 LTS Desktop Installation

1. Clone this repo on to the target machine
2. Run `setup/setup.sh` and reboot when prompted

## Running the Software

1. Run start.sh to start the demo software
2. Run stop.sh to stop the demo software
3. Open Chrome and navigate to http://localhost:8082 if running locally or use the IP address and port 8082 of the remote machine. (F11 can be used to put Chrome into full screen kiosk mode)
4. Add any combination of camera sources or video loops.
- 1 Hailo: 4 Sources
- 2 Hailo: 8 Sources
- 4 Hailo: 16 Sources

## Maintenance Operations

1. `docker system prune --all` followed by `docker volume prune --all` will completely clear out the software
2. `docker compose pull` will download the latest containers without running them 
