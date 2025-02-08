import express , { Request, Response } from "express";
import { fetchNextAvailableModuleForSetup } from "../utils/module_manager";
import { getConnectedMacAddresses, getConnectedModuleCounts } from "../utils/hardware_manager";

const { logger } = require("../utils/logger");
const router = express.Router();

// Endpoint to get the total number of connected modules
router.get("/total", async (req: Request, res: Response) => {
    try {
        const totalModules = await getConnectedModuleCounts();
        const esp32Macs = await getConnectedMacAddresses();

        res.json({
            totalConnectedDevices: totalModules,
            esp32Modules: esp32Macs.length,
            esp32MacAddresses: esp32Macs
        });
    } catch (error) {
        logger.error("Error in /total endpoint:", error);
        res.status(500).json({ error: "Failed to retrieve module information." });
    }
});

// Endpoint to get the next available module for setup
router.get("/next", async (req, res) => {
    try {
        const nextModule = await fetchNextAvailableModuleForSetup();
        if (nextModule) {
            //TODO send module display to [GREEN]
            res.json({ nextModule });
        } else {
            res.status(404).json({ message: "No available modules for setup." });
        }
    } catch (error) {
        res.status(500).json({ error: "Failed to retrieve connected modules." });
    }
});

// Endpoint to save a module's location
router.post("/location", (req : Request, res : Response) => {
    const { moduleId, row, col } = req.body;
    if (!moduleId || row === undefined || col === undefined) {
        return res.status(400).json({ error: "moduleId, row, and col are required." });
    }
    res.json({ message: "Module location saved." }); // Placeholder
});

// Endpoint to home all modules or a specific module
router.post("/home", (req : Request, res : Response) => {
    const { moduleId } = req.body;
    if (moduleId) {
        res.json({ message: `Module ${moduleId} homed.` });
    } else {
        res.json({ message: "All modules homed." });
    }
});

export default router;