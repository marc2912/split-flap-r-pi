module.exports = {
  apps: [
    {
      name: "splitflap",
      script: "/opt/splitflap/src/server.ts",
      interpreter: "node",
      interpreter_args: "-r ts-node/register",
      watch: false,
      autorestart: true,
      env: {
        NODE_ENV: "production",
        NODE_PATH: "/opt/splitflap/node_modules"
      }
    }
  ]
};