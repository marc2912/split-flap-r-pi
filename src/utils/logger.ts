
import type { Logform } from "winston";
const os = require("os");
const path = require("path");

const winston = require("winston");
const logFilePath = path.join(os.homedir(), "logs/split-flap.log");

const logger = winston.createLogger({
    level: "info",
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }), // ✅ Auto logs error stack traces
        winston.format.printf((info : Logform.TransformableInfo) => 
            info.stack 
                ? `${info.timestamp} [${info.level}]: ${info.message}\n${info.stack}`
                : `${info.timestamp} [${info.level}]: ${info.message}`
        )
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: logFilePath})
    ]
});

module.exports = { logger };
