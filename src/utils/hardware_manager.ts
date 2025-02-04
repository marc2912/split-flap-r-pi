import { exec } from "child_process";

// Fetch the MAC addresses of all connected modules, filtering only ESP32 MACs
export const getConnectedMacAddresses = async (): Promise<string[]> => {
    return new Promise((resolve, reject) => {
        exec("arp -a", (error, stdout, stderr) => {
            if (error) {
                console.error("Error fetching MAC addresses:", stderr);
                return reject(error);
            }

            // Extract MAC addresses from `arp -a` output
            const macRegex = /(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/g;
            const macAddresses = stdout.match(macRegex) || [];
            
            // Filter only ESP32 MAC addresses (OUI prefix for Espressif: 24:6F:28, 3C:71:BF, 7C:DF:A1, etc.)
            const esp32Prefixes = ["24:6F:28", "3C:71:BF", "7C:DF:A1", "AC:67:B2", "BC:DD:C2"];
            const esp32Macs = macAddresses.filter(mac => 
                esp32Prefixes.some(prefix => mac.toUpperCase().startsWith(prefix))
            );

            resolve(esp32Macs);
        });
    });
};

