import express , { Request, Response } from "express";
import { getEsp32MacPrefixes } from "../utils/hardware_manager";
const { logger } = require("../utils/logger");

const router = express.Router();
const adminToken = process.env.ADMIN_TOKEN || "";

const checkAuthorization =(req: Request, res: Response) : boolean => {
    var submittedToken = req.headers.authorization?.split(" ")[1];

    if (adminToken ===  "" || submittedToken !== adminToken) {
        logger.info("admin requested with invalid token: " + submittedToken);
        res.status(401).json({ error: "Unauthorized" });
        return false; 
    }
    return true;
}

router.post("/get-mac-prefixes", async (req: Request, res: Response) => {

    if (!checkAuthorization(req, res)) {
        return;
    }
    const esp32Prefixes = await getEsp32MacPrefixes();
    res.json({ esp32Prefixes });
});



export default router;