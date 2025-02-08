import express, { Request, Response } from "express";
import net from "net";
import { sendPayloadToModule } from "./utils/tcp_manager";
const { logger } = require("./utils/logger");


process.on("uncaughtException", (err) => {
    logger.error("🔥 Uncaught Exception:", err);
    process.exit(1); // Exit to prevent corrupted state
});

process.on("unhandledRejection", (reason, promise) => {
    logger.error("🔥 Unhandled Promise Rejection:", reason);
});

const app = express();
const PORT: number = Number(process.env.PORT) || 3000;
const TCP_PORT: number = 4000; // Port for module communication

app.use(express.json());

// Define expected body structure
interface SendPayloadBody {
    moduleIp: string;
    payload: {
        display: string;
        speed: number;
    };
}

// Import routes
import setupRoutes from "./routes/setup";
import moduleRoutes from "./routes/modules";
import layoutRoutes from "./routes/layout";
import adminRoutes from "./routes/admin";

app.use(express.json()); 
app.use(express.urlencoded({ extended: true })); // Handles URL-encoded data

// Use routes
app.use("/setup", setupRoutes);
app.use("/modules", moduleRoutes);
app.use("/layout", layoutRoutes);
app.use("/admin", adminRoutes);

// Endpoint to send a payload to a module
app.post("/tcp/send", async (req: Request, res: Response): Promise<void> => {
    const body = req.body as { moduleIp: string; payload: { display: string; speed: number } };

    if (!body.moduleIp || !body.payload) {
        res.status(400).json({ error: "Module IP and payload are required." });
        return;
    }

    try {
        const response = await sendPayloadToModule(body.moduleIp, body.payload);
        res.json({ message: `Payload sent to ${body.moduleIp}`, response });
    } catch (error) {
        res.status(500).json({ error: `Failed to send payload to ${body.moduleIp}` });
    }
});

// Start Express server
const server = app.listen(PORT, () => {
    logger.info(`REST API running on port ${PORT}`);
});

// Create TCP server
const tcpServer = net.createServer((socket) => {
    logger.info("Module connected:", {ip: socket.remoteAddress});

    socket.on("data", (data) => {
        logger.info("Received from module:", {data: data.toString()});
        // Handle data from module
    });

    socket.on("end", () => {
        logger.info("Module disconnected.");
    });

    socket.on("error", (err) => {
        logger.error("TCP Error:", err);
    });
});

tcpServer.listen(TCP_PORT, () => {
    logger.info(`TCP server running on port ${TCP_PORT}`);
});

export default app;
