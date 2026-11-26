import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// One self-contained script (public/widget.js) that any site can embed with a <script> tag.
export default defineConfig({
  plugins: [react()],
  define: { "process.env.NODE_ENV": JSON.stringify("production") },
  build: {
    outDir: "../../public",
    emptyOutDir: false,
    cssCodeSplit: false,
    sourcemap: false,
    lib: { entry: "src/index.tsx", name: "AgentDeskWidget", formats: ["iife"], fileName: () => "widget.js" },
  },
  test: { environment: "node" },
});
