import express , { Request, Response } from "express";
import { getEsp32MacPrefixes } from "../utils/hardware_manager";
import { loadConfig, saveConfig } from "../utils/config_handler";

const { logger } = require("../utils/logger");
const router = express.Router();

router.post("/get-mac-prefixes", async (req: Request, res: Response) => {

    const esp32Prefixes = await getEsp32MacPrefixes();
    res.json({ esp32Prefixes });
});

router.post("/reset-env", async (req: Request, res: Response) => {

    logger.info("Resetting environment");
    saveConfig({ modules: [], layout: [], pairingKey: "" });
    res.json({ message: "Environment reset" });
});

export default router;