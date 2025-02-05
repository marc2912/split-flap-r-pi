import express, { Request, Response } from "express";
import net from "net";
import { sendPayloadToModule } from "./utils/tcp_manager";

process.on("uncaughtException", (err) => {
    console.error("🔥 Uncaught Exception:", err);
    console.error(err.stack);
    process.exit(1); // Exit to prevent corrupted state
});

process.on("unhandledRejection", (reason, promise) => {
    console.error("🔥 Unhandled Promise Rejection:", reason);
    console.error(reason instanceof Error ? reason.stack : reason);
});
console.log('NODE_PATH:', process.env.NODE_PATH);
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

app.use(express.json()); 
app.use(express.urlencoded({ extended: true })); // Handles URL-encoded data

// Use routes
app.use("/setup", setupRoutes);
app.use("/modules", moduleRoutes);
app.use("/layout", layoutRoutes);

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
    console.log(`REST API running on port ${PORT}`);
});

// Create TCP server
const tcpServer = net.createServer((socket) => {
    console.log("Module connected:", socket.remoteAddress);

    socket.on("data", (data) => {
        console.log("Received from module:", data.toString());
        // Handle data from module
    });

    socket.on("end", () => {
        console.log("Module disconnected.");
    });

    socket.on("error", (err) => {
        console.error("TCP Error:", err.message);
    });
});

tcpServer.listen(TCP_PORT, () => {
    console.log(`TCP server running on port ${TCP_PORT}`);
});

export default app;
