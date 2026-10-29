#!/usr/bin/env node
// SPDX-License-Identifier: MIT
// `npx mgp demo` entry point.
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const demoPath = join(__dirname, "..", "demo", "index.ts");
const args = [demoPath, ...process.argv.slice(2)];
const child = spawn(process.execPath, ["--experimental-strip-types", ...args], {
    stdio: "inherit",
    env: process.env,
});
child.on("exit", (code) => process.exit(code ?? 1));
