import fs from "fs";
import path from "path";
import { exec } from "child_process";
import dotenv from "dotenv";

dotenv.config();
const {logger} = require("./logger");


const CONFIG_FILE = path.join(__dirname, process.env.CONFIG_FILE || "../splitflap-config.json");
const LOCK_FILE = path.join(__dirname, "../splitflap-config.lock");

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

// Load configuration from file with file locking
export const loadConfig = (): Config => {
    let retries = 120; // Maximum retries (120 * 100ms = 12 seconds)

    while (fileExists(LOCK_FILE) && retries > 0) {
        retries--;
        logger.info("Waiting for lock file to be released... "+ (120 - retries) + "s / 120s");
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100); 

        if (retries === 0) {
            logger.error("Failed to acquire lock file. Exiting.");
            process.exit(1);
        }
    }

    if (fileExists(CONFIG_FILE)) {
        return JSON.parse(fs.readFileSync(CONFIG_FILE, "utf-8"));
    }

    return { modules: [], layout: [], pairingKey: "" };
};

// Save configuration to file with file locking
export const saveConfig = (config: Config): void => {
    try {
        fs.writeFileSync(LOCK_FILE, "lock");
        fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
    } catch (error) {
        logger.error("Error saving config:", error);
    } finally {
        if (fileExists(LOCK_FILE)) fs.unlinkSync(LOCK_FILE);
    }
};

// Update Raspberry Pi's Wi-Fi configuration
export const updateWiFiConfig = (ssid: string, password: string): boolean => {
    const command = `nmcli dev wifi connect "${ssid}" password "${password}" ifname wlan1`;

    exec(command, (error, stdout, stderr) => {
        if (error) {
        logger.error("Error connecting to wifi:", stderr);
        return false;
        }
        logger.log("Connected successfully:", stdout);
        return true;
    });
    return false;
};

// Checks to see if the Raspberry Pi is connected to a Wi-Fi network
export const checkWifiConnection = (): boolean => {
    return false;
};