import { loadConfig, saveConfig, updateWiFiConfig } from "../utils/config_handler";
import express , { Request, Response } from "express";


const {logger} = require("../utils/logger");
const router: express.Router = express.Router();

let config = loadConfig();

// Endpoint to set the Wi-Fi SSID and password from app.
router.post("/ssid", async (req: Request, res: Response) => {
    if (config.pairingKey && config.pairingKey !== "") {
        return res.status(403).json({ error: "SSID configuration is locked after pairing." });
    }

    const { ssid, password } = req.body;
    if (!ssid || !password) {
        return res.status(400).json({ error: "SSID and password are required." });
    }

    try {
        const success = await updateWiFiConfig(ssid, password);
        if (success) {
            const pairingKey = Math.random().toString(36).substring(2, 10);
            config.pairingKey = pairingKey;
            saveConfig(config);
            return res.json({ pairingKey });
        } else {
            return res.status(500).json({ message: "Failed to connect to your home network." });
        }
    } catch (error) {
        logger.error("Wi-Fi configuration error:", error);
        return res.status(500).json({ error: "Internal server error while updating Wi-Fi." });
    }
});

export default router;
