import express , { Request, Response } from "express";
import { getEsp32MacPrefixes } from "../utils/hardware_manager";
const { logger } = require("../utils/logger");
const router = express.Router();

router.post("/get-mac-prefixes", async (req: Request, res: Response) => {

    const esp32Prefixes = await getEsp32MacPrefixes();
    res.json({ esp32Prefixes });
});

export default router;