module.exports = {
  apps: [
    {
      name: 'splitflap',
      script: '/opt/splitflap/src/server.ts',
      interpreter: '/opt/splitflap/node_modules/.bin/ts-node',
      env: {
        NODE_PATH: '/opt/splitflap/node_modules',
        // Add other environment variables as needed
      },
    },
  ],
};