import { loadConfig, saveConfig, updateWiFiConfig } from "../utils/config_handler";
import express , { Request, Response } from "express";

const {logger} = require("../utils/logger");
const router: express.Router = express.Router();

let config = loadConfig();

// ✅ Correct Function Signature
router.post("/ssid", (req: Request, res: Response) => {
    if (config.pairingKey) {
        return res.status(403).json({ error: "SSID configuration is locked after pairing." });
    }

    const { ssid, password } = req.body;
    if (!ssid || !password) {
        return res.status(400).json({ error: "SSID and password are required." });
    }

    // Update Wi-Fi settings and restart networking
    updateWiFiConfig(ssid, password);

    res.json({ message: "Wi-Fi SSID and password set successfully. Pi will attempt to connect." });
});


// Endpoint to generate a pairing key
router.post("/pairing", (req: Request, res: Response) => {
    const pairingKey = Math.random().toString(36).substring(2, 10);
    config.pairingKey = pairingKey;
    saveConfig(config);
    res.json({ pairingKey });
});

export default router;
