// Records one signed-in Microsoft browser session (auth/maker.json) used by every UI test.
// The demo identity is typed in the app (Constitution V), so one Microsoft account covers every persona.
// Usage: npm run auth   (a browser opens: sign in, wait for the Timekeeper sign-in panel, then close the window)
import { spawnSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import 'dotenv/config';

if (!process.env.TK_APP_URL) {
  console.error('Set TK_APP_URL (run-harness.ps1 sets it for you, or put it in .env).');
  process.exit(1);
}
mkdirSync('auth', { recursive: true });
console.log('Sign in with your Microsoft account. When the Timekeeper sign-in panel shows, close the browser window.');
// shell: true on Windows, so quote the URL: its '&' would otherwise split the command
const url = process.platform === 'win32' ? `"${process.env.TK_APP_URL}"` : process.env.TK_APP_URL;
const r = spawnSync('npx', ['playwright', 'codegen', '--save-storage=auth/maker.json', url], {
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
process.exit(r.status ?? 0);
