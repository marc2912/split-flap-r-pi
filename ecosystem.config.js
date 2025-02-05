module.exports = {
  apps: [
    {
      name: "splitflap",
      script: "/opt/splitflap/src/server.ts",
      interpreter: "/home/splitflap/.npm-global/bin/ts-node",
      node_args: "--loader ts-node/esm",
      watch: false,
      autorestart: true,
      env: {
        NODE_ENV: "production",
        NODE_OPTIONS: "--loader ts-node/esm",
        NODE_PATH: "/opt/splitflap/node_modules"
      }
    }
  ]
};