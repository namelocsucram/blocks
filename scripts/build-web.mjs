import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { build } from "esbuild";

const workspaceRoot = resolve(import.meta.dirname, "..");
const appRoot = resolve(workspaceRoot, "blocks");
const sourcePath = resolve(appRoot, "stoke_files/stoke-app.jsx");
const bundlePath = resolve(workspaceRoot, ".web-build/stoke.bundle.js");
const templatePath = resolve(appRoot, "stoke_files/index.template.html");
const indexPath = resolve(appRoot, "stoke_files/index.html");
const stokePath = resolve(appRoot, "stoke_files/stoke.html");

mkdirSync(dirname(bundlePath), { recursive: true });

await build({
  entryPoints: [sourcePath],
  bundle: true,
  minify: true,
  format: "iife",
  target: ["safari15", "ios15"],
  outfile: bundlePath,
  logLevel: "info"
});

const template = readFileSync(templatePath, "utf8");
const bundle = readFileSync(bundlePath, "utf8");
const html = template.replace("<!-- STOKE_BUNDLE -->", () => `<script>\n${bundle}\n</script>`);

writeFileSync(indexPath, html);
writeFileSync(stokePath, html);
