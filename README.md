# SplitFlap-Pi

A Raspberry Pi-based controller for a modular split flap display.

## Features
- Creates an Access Point (AP) for module setup
- Connects to a home network for remote control
- REST API for controlling modules
- TCP server for module communication
- TypeScript + Node.js backend

## Setup & Installation

To install and run the project, use the following commands:

1. Install Raspberry Pi OS Lite via Raspberry Pi Imager
2. Create a user account and enable SSH, use public key authentication.
3. Connect Raspberry Pi to Ethernet and power on.
4. SSH into the Pi
   **ssh pi@<RPI_IP_ADDRESS>**
5. Install git
   **sudo apt-get install git**
6. Clone the repository
   **git clone https://github.com/marc2912/split-flap-r-pi.git**
7. Change script to be executable
   **chmod +x split-flap-r-pi/install.sh**
8. Run the install script
   **split-flap-r-pi/install.sh**

This will install both the application and setup AP mode on the Pi.


---

## API Endpoints

### Setup

#### `POST /setup/ssid`
- **Description:** Sets the WiFi SSID and password for the Pi.
- **Body:**
  {
    "ssid": "YourWiFiName",
    "password": "YourWiFiPassword"
  }
- **Response:**
  {
    "message": "Wi-Fi SSID and password set successfully."
  }

#### `POST /setup/pairing`
- **Description:** Generates a pairing key for mobile apps.
- **Response:**
  {
    "pairingKey": "abcdefgh"
  }

---

### Modules

#### `GET /modules/total`
- **Description:** Returns the total number of connected modules.
- **Response:**
  {
    "totalModules": 5
  }

#### `POST /modules/save`
- **Description:** Saves the layout of the split flap modules.
- **Body:**
  {
    "layout": [
      { "row": 1, "column": 1, "moduleId": "000001" },
      { "row": 1, "column": 2, "moduleId": "000002" }
    ]
  }
- **Response:**
  {
    "message": "Layout saved."
  }

#### `GET /modules/next`
- **Description:** Returns the next module available for setup.
- **Response:**
  {
    "moduleId": "000005"
  }

#### `POST /modules/location`
- **Description:** Saves a module’s location.
- **Body:**
  {
    "moduleId": "000001",
    "row": 1,
    "column": 1
  }
- **Response:**
  {
    "message": "Module location saved."
  }

---

### Display Controls

#### `POST /display`
- **Description:** Sends values to all modules.
- **Body:**
  {
    "modules": [
      { "moduleId": "000001", "character": "A" },
      { "moduleId": "000002", "character": "B" }
    ]
  }
- **Response:**
  {
    "message": "Display updated."
  }

#### `POST /home`
- **Description:** Sends a homing command to a specific module or all modules.
- **Body (optional):**
  {
    "moduleId": "000001"
  }
- **Response:**
  {
    "message": "Module homed."
  }

---

## License
This project is licensed under the **MIT License**. See `LICENSE` for details.