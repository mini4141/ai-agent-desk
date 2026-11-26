import { defineConfig } from "@playwright/test";

// URLs default to the local stack; override for the cloud run (see scripts/capture-proof.sh phase2).
export const urls = {
  api: process.env.API_URL ?? "http://localhost:3000",
  help: process.env.HELP_URL ?? "http://localhost:3001",
  console: process.env.CONSOLE_URL ?? "http://localhost:5173",
  phone: process.env.PHONE_URL ?? "http://localhost:5175",
};
const reportDir = process.env.PW_REPORT_DIR ?? "../../proof/phase1-local/tests";

export default defineConfig({
  testDir: "./tests",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  workers: 1, // tests share one seeded database
  retries: process.env.CI ? 1 : 0,
  reporter: [
    ["list"],
    ["html", { outputFolder: `${reportDir}/playwright-report`, open: "never" }],
    ["junit", { outputFile: `${reportDir}/playwright-junit.xml` }],
  ],
  use: {
    viewport: { width: 1280, height: 860 },
    permissions: ["microphone"],
    launchOptions: {
      // Fake microphone so hold-to-talk works headlessly (SPECS F4).
      args: [
        "--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream", "--autoplay-policy=no-user-gesture-required",
        // Cloud runs feed a Polly-synthesised Japanese utterance to the fake microphone so Transcribe has real speech to hear.
        ...(process.env.FAKE_AUDIO ? [`--use-file-for-fake-audio-capture=${process.env.FAKE_AUDIO}`] : []),
      ],
    },
  },
  projects: [{ name: "chromium", use: { browserName: "chromium" } }],
});
