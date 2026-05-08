#!/usr/bin/env node
import { readdirSync, readFileSync, writeFileSync, existsSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const scansDir = join(repoRoot, "docs", "scans");
const outFile = join(repoRoot, "docs", "scans.json");

if (!existsSync(scansDir)) {
    console.error(`No docs/scans directory at ${scansDir}`);
    process.exit(1);
}

const folders = readdirSync(scansDir, { withFileTypes: true })
    .filter(d => d.isDirectory() && !d.name.startsWith("."));

const scans = [];
const warnings = [];

for (const folder of folders) {
    const dir = join(scansDir, folder.name);
    const metaPath = join(dir, "meta.json");
    if (!existsSync(metaPath)) {
        warnings.push(`skipped ${folder.name} (no meta.json)`);
        continue;
    }
    let meta;
    try {
        meta = JSON.parse(readFileSync(metaPath, "utf8"));
    } catch (err) {
        warnings.push(`skipped ${folder.name} (meta.json parse error: ${err.message})`);
        continue;
    }

    const fileIfExists = (name) => {
        const path = join(dir, name);
        return existsSync(path) ? `scans/${folder.name}/${name}` : null;
    };

    scans.push({
        id: meta.id || folder.name,
        name: meta.name || folder.name,
        createdAt: meta.createdAt || new Date(statSync(metaPath).mtime).toISOString(),
        durationSeconds: meta.durationSeconds ?? 0,
        meshAnchorCount: meta.meshAnchorCount ?? 0,
        vertexCount: meta.vertexCount ?? 0,
        triangleCount: meta.triangleCount ?? 0,
        meshFile: fileIfExists("mesh.obj"),
        usdzFile: fileIfExists("mesh.usdz"),
        videoFile: fileIfExists("video.mp4")
    });
}

scans.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

writeFileSync(outFile, JSON.stringify({ scans }, null, 2) + "\n");

console.log(`Indexed ${scans.length} scan${scans.length === 1 ? "" : "s"} → docs/scans.json`);
for (const w of warnings) console.warn(`  ⚠ ${w}`);
