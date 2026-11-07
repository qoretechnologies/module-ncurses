// Copyright 2026 Qore Technologies, s.r.o. SPDX-License-Identifier: MIT
import { fileURLToPath } from 'node:url';
const terminalModule = fileURLToPath(new URL('../terminal.mjs', import.meta.url));
export default {
  framework: '@storybook/html-vite',
  stories: ['../generated/*.stories.js'],
  addons: [],
  core: { disableTelemetry: true },
  async viteFinal(config) {
    config.plugins = [...(config.plugins ?? []), {
      name: 'native-terminal-registration-reload',
      handleHotUpdate({ file, server }) {
        if (file !== terminalModule) { return; }
        // A CustomElementRegistry cannot replace a registered constructor. Start
        // a fresh document instead of evaluating another definition in that registry.
        server.ws.send({ type: 'full-reload' }); return [];
      },
    }];
    config.server = { ...config.server,
      // Storybook owns the HTTP server. Vite needs it explicitly for proxy WS upgrades.
      ...(config.server?.middlewareMode && config.server?.hmr?.server
        ? { middlewareMode: { server: config.server.hmr.server } } : {}),
      watch: { ...config.server?.watch, ignored: [...(config.server?.watch?.ignored ?? []), '**/artifacts/**', '**/baselines/**', '**/storybook-static/**'] },
      proxy: { '/native': { target: 'ws://127.0.0.1:6007', ws: true } },
    };
    // Storybook's published preview runtime is one prebundled ~812 kB module.
    // Keep its measured vendor budget separate from the adapter's 400 kB test budget.
    config.build = { ...config.build, chunkSizeWarningLimit: 900, rolldownOptions: { ...config.build?.rolldownOptions,
      output: { ...config.build?.rolldownOptions?.output, codeSplitting: {
        groups: [{ name: 'storybook', test: /node_modules\/storybook\//, maxSize: 400000 }],
      } },
    } };
    return config;
  },
};
