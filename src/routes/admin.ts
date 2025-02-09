import express , { Request, Response } from "express";
import { deleteConnectionByDevice, getEsp32MacPrefixes } from "../utils/hardware_manager";
import { loadConfig, saveConfig } from "../utils/config_handler";

const { logger } = require("../utils/logger");
const router = express.Router();

router.post("/get-mac-prefixes", async (req: Request, res: Response) => {

    const esp32Prefixes = await getEsp32MacPrefixes();
    res.json({ esp32Prefixes });
});

router.post("/reset-env", async (req: Request, res: Response) => {
    logger.info("Resetting environment");
    if (await deleteConnectionByDevice()) {
        saveConfig({ modules: [], layout: [], pairingKey: "" });
        res.json({ message: "Environment reset" });
    } else {
        res.status(500).json({ message: "Error resetting environmen, check log file." });
    }
});

export default router;