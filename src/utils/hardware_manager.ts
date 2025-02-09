import { exec } from "child_process";
const {logger} = require("./logger");
import util from "util";

const IEEE_OUI_URL = "https://standards-oui.ieee.org/oui.txt";

const execPromise = util.promisify(exec);

// Cache variables
let cachedEsp32Prefixes: string[] = [];
let cacheTimestamp: number = 0;
const CACHE_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Fetches the MAC addresses of connected ESP32 modules via wlan0.
 * Uses `arp -a` and filters by known ESP32 MAC prefixes.
 */
export const getConnectedMacAddresses = async (): Promise<string[]> => {
    return new Promise(async (resolve, reject) => {
        exec("arp -a | grep wlan0", async (error, stdout, stderr) => {
            if (error) {
                logger.error("Error fetching MAC addresses:", stderr);
                return reject(error);
            }
            var retValue = stdout.toUpperCase();
            // Extract MAC addresses using regex
            const macRegex = /(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/g;
            const macAddresses = retValue.match(macRegex) || [];
            logger.info("Detected MACs: " + retValue);
            // Get ESP32 MAC prefixes (cached or fetched)
            const esp32Prefixes = await getEsp32MacPrefixes();

            // Filter only ESP32 devices
            const esp32Macs = macAddresses.filter(mac =>
                esp32Prefixes.some(prefix => mac.startsWith(prefix))
            );

            logger.info("Detected ESP32 MACs:" + esp32Macs.join(", "));
            resolve(esp32Macs);
        });
    });
};

/**
 * Fetches the latest ESP32 MAC prefixes from IEEE OUI list, with caching.
 */
export const getEsp32MacPrefixes = async (): Promise<string[]> => {
    const now = Date.now();

    // Use cached values if still valid
    if (cachedEsp32Prefixes.length > 0 && now - cacheTimestamp < CACHE_DURATION_MS) {
        logger.info("Using cached ESP32 prefixes.");
        return cachedEsp32Prefixes;
    }

    logger.info("Fetching new ESP32 MAC prefixes...");
    try {
        const response = await fetch(IEEE_OUI_URL);
        const text: string = await response.text();
        const lines: string[] = text.split("\n");

        // Extract all Espressif prefixes
        const esp32Prefixes = lines
            .filter((line: string) => line.toLowerCase().includes("espressif"))
            .map((line: string) => line.substring(0, 8).trim().replace(/-/g, ":").toUpperCase());

        // Update cache
        cachedEsp32Prefixes = esp32Prefixes;
        cacheTimestamp = now;

        return esp32Prefixes;
    } catch (error) {
        logger.error("Failed to fetch OUI list:", error);
        return [];
    }
};

/**
 * Returns the number of connected clients to wlan0 using `iw`.
 * More reliable than ARP-based counting.
 */
export const getConnectedModuleCounts = async (): Promise<number> => {
    return new Promise((resolve, reject) => {
        exec("iw dev wlan0 station dump | grep 'Station' | wc -l", (error, stdout, stderr) => {
            if (error) {
                logger.error("Error fetching module count:", stderr);
                return reject(error);
            }

            const count = parseInt(stdout.trim(), 10) || 0;
            logger.info("Total connected modules: " + count);
            resolve(count);
        });
    });
};

export const deleteConnectionByDevice = async (): Promise<boolean> => {
    try {
        const device = "wlan1";
        // Get the connection name associated with the given device
        const { stdout } = await execPromise(`nmcli -t -f NAME,DEVICE connection show | grep ":${device}" | cut -d: -f1`);
        const connName = stdout.trim();

        if (!connName) {
            logger.info(`No connection found for device: wlan1`);
            return true;
        }

        // Delete the connection
        await execPromise(`sudo nmcli connection delete "${connName}"`);
        logger.info("Deleted connection: " + connName + " on device: wlan1");
        return true;
    } catch (error: any) 
    {
        logger.error("Error deleting connection for wlan1: ", error);
        return false;
    }
};