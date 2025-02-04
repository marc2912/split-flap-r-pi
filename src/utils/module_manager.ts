import { loadConfig, saveConfig } from "./config_handler.ts";
import { getConnectedMacAddresses } from "./hardware_manager.ts";

interface Module {
    "module-mac-address": string;
}


// Fetch the next available module for setup
export const fetchNextAvailableModuleForSetup = async (): Promise<string | null> => {
    const config = loadConfig();
    
    const connectedMacAddresses: string[] = await getConnectedMacAddresses(); 

    const configuredMacAddresses: string[] = config.modules.map((module: Module) => module["module-mac-address"]);

    for (const connectedMacAddress of connectedMacAddresses) {
        if (!configuredMacAddresses.includes(connectedMacAddress)) {
            return connectedMacAddress;
        }
    }
    return null;
};

