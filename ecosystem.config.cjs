module.exports = {
  apps: [
    {
      name: "splitflap",
      script: "./src/server.ts",
      interpreter: "node",
      args: "-r ts-node/register",
      cwd: "/opt/splitflap",
      watch: false,
      autorestart: true,
      env: {
        NODE_ENV: "production",
        TS_NODE_TRANSPILE_ONLY: "true",
        TS_NODE_COMPILER_OPTIONS: '{"module":"NodeNext"}'
      }
    }
  ]
};