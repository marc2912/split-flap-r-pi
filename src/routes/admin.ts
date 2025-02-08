import express , { Request, Response } from "express";
import { getEsp32MacPrefixes } from "../utils/hardware_manager";

const router = express.Router();
const adminToken = process.env.ADMIN_TOKEN || "";

const checkAuthorization =(req: Request, res: Response) : boolean => {
    var submittedToken = req.headers.authorization?.split(" ")[1];
    console.log(submittedToken);
    if (adminToken ===  "" || submittedToken !== adminToken) {
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