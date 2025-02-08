import { Request, Response, NextFunction } from "express";
import { loadConfig } from "../utils/config_handler";
const { logger } = require("../utils/logger");

export const validatePairingToken = (req: Request, res: Response, next: NextFunction) => {
    const token = req.headers.authorization; 

    if (!token) {
        return res.status(401).json({ error: "Unauthorized: Token is required" });
    }
    const config = loadConfig();

    if (token !== config.pairingKey) {
        return res.status(403).json({ error: "Forbidden: Invalid token" });
    }

    next();
};

export const validateAdminToken = (req: Request, res: Response, next: NextFunction) => {
    var submittedToken = req.headers.authorization?.split(" ")[1];
    const adminToken = process.env.ADMIN_TOKEN || "";
    if (adminToken ===  "" || submittedToken !== adminToken) {
        logger.info("admin requested with invalid token: " + submittedToken);
        return res.status(401).json({ error: "Unauthorized" });; 
    }
    next();
}
