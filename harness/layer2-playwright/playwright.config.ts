import { defineConfig } from '@playwright/test';
import { existsSync } from 'node:fs';
import 'dotenv/config';

// One recorded Microsoft sign-in for every UI project; each test types its persona's email in the app.
const maker = existsSync('auth/maker.json') ? 'auth/maker.json' : undefined;

export default defineConfig({
  testDir: './tests',
  timeout: 120_000,                 // canvas apps can take a while to start
  expect: { timeout: 30_000 },
  retries: 1,
  workers: 1,                       // tests share one demo dataset: run serially
  reporter: [
    ['list'],
    ['json', { outputFile: '../reports/layer2-results.json' }],
    ['html', { outputFolder: '../reports/layer2-html', open: 'never' }],
  ],
  use: {
    viewport: { width: 1440, height: 900 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'api', testMatch: /api-contract\.spec\.ts/ },
    { name: 'theme', testMatch: /theme-contrast\.spec\.ts/ },
    { name: 'employee', testMatch: /us1-.*\.spec\.ts/, use: { storageState: maker } },
    { name: 'manager', testMatch: /us2-.*\.spec\.ts/, use: { storageState: maker } },
    { name: 'unregistered', testMatch: /unregistered\.spec\.ts/, use: { storageState: maker } },
  ],
});
