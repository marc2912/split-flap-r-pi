import net from "net";

/**
 * Sends a payload to a specific module via TCP.
 * @param {string} moduleIp - The IP address of the module.
 * @param {Object} payload - The JSON payload to send.
 * @returns {Promise} Resolves with the module's response, rejects on error.
 */
export const sendPayloadToModule = (moduleIp: string, payload: { display: string; speed: number }): Promise<any> => {
    return new Promise((resolve, reject) => {
        const client = new net.Socket();
        const message = JSON.stringify({ payload });

        client.connect(4000, moduleIp, () => {
            console.log(`Connected to module at ${moduleIp}`);
            client.write(message);
        });

        client.on("data", (data) => {
            try {
                const response = JSON.parse(data.toString());
                console.log(`Response from module:`, response);
                client.destroy();
                resolve(response);
            } catch (error) {
                console.error("Error parsing module response:", error);
                reject(new Error("Invalid response format from module"));
            }
        });

        client.on("error", (err) => {
            console.error(`Error sending data to ${moduleIp}:`, err.message);
            reject(err);
        });

        client.on("close", () => {
            console.log(`Connection to ${moduleIp} closed.`);
        });
    });
};

