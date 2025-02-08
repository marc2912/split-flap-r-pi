import fs from "fs";
import path from "path";
import { exec } from "child_process";
import dotenv from "dotenv";

dotenv.config();

const CONFIG_FILE = path.join(__dirname, process.env.CONFIG_FILE || "../splitflap-config.json");
const LOCK_FILE = path.join(__dirname, "../splitflap-config.lock");
const WPA_SUPPLICANT_FILE = process.env.WPA_SUPPLICANT_FILE || "/etc/wpa_supplicant/wpa_supplicant.conf";

// ✅ Proper TypeScript Typing
interface Config {
    modules: { "module-mac-address": string }[];
    layout: { row: number; column: number; moduleId: string }[];
    pairingKey: String;
}

const fileExists = (filePath: string): boolean => {
    try {
        fs.accessSync(filePath, fs.constants.F_OK);
        return true;
    } catch (err) {
        return false;
    }
};

// ✅ Load configuration from file with file locking
export const loadConfig = (): Config => {
    let retries = 120; // Maximum retries (120 * 100ms = 12 seconds)

    while (fileExists(LOCK_FILE) && retries > 0) {
        retries--;
        console.log(`Waiting for lock file to be released... ${120 - retries}s / 120s`);
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100); // ✅ Non-blocking sleep alternative

        if (retries === 0) {
            console.error("Failed to acquire lock file. Exiting.");
            process.exit(1);
        }
    }

    if (fileExists(CONFIG_FILE)) {
        return JSON.parse(fs.readFileSync(CONFIG_FILE, "utf-8"));
    }

    return { modules: [], layout: [], pairingKey: "" };
};

// ✅ Save configuration to file with file locking
export const saveConfig = (config: Config): void => {
    try {
        fs.writeFileSync(LOCK_FILE, "lock");
        fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
    } catch (error) {
        console.error("Error saving config:", error);
    } finally {
        if (fileExists(LOCK_FILE)) fs.unlinkSync(LOCK_FILE);
    }
};

// ✅ Update Raspberry Pi's Wi-Fi configuration
export const updateWiFiConfig = (ssid: string, password: string): void => {
    const wifiConfig = `
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="${ssid}"
    psk="${password}"
    key_mgmt=WPA-PSK
}
`;
    fs.writeFileSync("/tmp/wpa_supplicant.conf", wifiConfig);
    console.log("Wi-Fi configuration updated in /tmp.");

    // ✅ Backup existing config before overwriting
    exec(`sudo cp ${WPA_SUPPLICANT_FILE} /etc/wpa_supplicant/wpa_supplicant.conf.bak`, (backupError) => {
        if (backupError) {
            console.error("Error backing up existing Wi-Fi config:", backupError.message);
        } else {
            console.log("Existing Wi-Fi config backed up.");
        }

        // ✅ Overwrite with new config and reload Wi-Fi
        exec(`sudo cp /tmp/wpa_supplicant.conf ${WPA_SUPPLICANT_FILE} && sudo wpa_cli -i wlan0 reconfigure`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error restarting Wi-Fi: ${stderr}`);
                console.log("Restoring previous Wi-Fi configuration...");
                exec(`sudo cp /etc/wpa_supplicant/wpa_supplicant.conf.bak ${WPA_SUPPLICANT_FILE} && sudo wpa_cli -i wlan0 reconfigure`, (restoreError) => {
                    if (restoreError) {
                        console.error("Failed to restore Wi-Fi settings! Manual intervention needed.");
                    } else {
                        console.log("Previous Wi-Fi settings restored.");
                    }
                });
            } else {
                console.log("Wi-Fi restarted successfully with new settings.");
            }
        });
    });
};