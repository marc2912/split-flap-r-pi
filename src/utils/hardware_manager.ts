import { exec } from "child_process";

/**
 * Fetches the MAC addresses of connected ESP32 modules via wlan0.
 * Uses `arp -a` and filters by known ESP32 MAC prefixes.
 */
export const getConnectedMacAddresses = async (): Promise<string[]> => {
    return new Promise((resolve, reject) => {
        exec("arp -a | grep wlan0", (error, stdout, stderr) => {
            if (error) {
                console.error("Error fetching MAC addresses:", stderr);
                return reject(error);
            }

            // Extract MAC addresses using regex
            const macRegex = /(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/g;
            const macAddresses = stdout.match(macRegex) || [];

            // Known ESP32 OUI prefixes
            const esp32Prefixes = ["24:6F:28", "3C:71:BF", "7C:DF:A1", "AC:67:B2", "BC:DD:C2"];
            
            // Filter only ESP32 devices
            const esp32Macs = macAddresses.filter(mac =>
                esp32Prefixes.some(prefix => mac.toUpperCase().startsWith(prefix))
            );

            console.log(`Detected ESP32 MACs: ${esp32Macs.join(", ")}`);
            resolve(esp32Macs);
        });
    });
};

/**
 * Returns the number of connected clients to wlan0 using `iw`.
 * More reliable than ARP-based counting.
 */
export const getConnectedModules = async (): Promise<number> => {
    return new Promise((resolve, reject) => {
        exec("iw dev wlan0 station dump | grep 'Station' | wc -l", (error, stdout, stderr) => {
            if (error) {
                console.error("Error fetching module count:", stderr);
                return reject(error);
            }

            const count = parseInt(stdout.trim(), 10) || 0;
            console.log(`Total connected modules: ${count}`);
            resolve(count);
        });
    });
};