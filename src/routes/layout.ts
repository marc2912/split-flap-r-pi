import express, { Request, Response } from "express";

const router = express.Router();

// Endpoint to save the split flap layout
router.post("/", (req : Request, res : Response) => {
    const { layout } = req.body;
    if (!layout || !Array.isArray(layout)) {
        return res.status(400).json({ error: "Valid layout array is required." });
    }
    res.json({ message: "Layout saved." }); // Placeholder
});

// Endpoint to retrieve the current layout
router.get("/", (req, res) => {
    res.json({ layout: [] }); // Placeholder
});

// Endpoint to update the display with module values
router.post("/display", (req : Request, res : Response) => {
    const { modules } = req.body;
    if (!modules || !Array.isArray(modules)) {
        return res.status(400).json({ error: "Valid modules array is required." });
    }
    res.json({ message: "Display updated." }); // Placeholder
});

export default router;