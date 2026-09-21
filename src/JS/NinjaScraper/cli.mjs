#!/usr/bin/env node
import { createWriteStream } from "node:fs";
import { mkdir, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { parseArgs } from "node:util";

const apiUrl =
  "https://api.runevents.net/api/sessions-and-speakers/external-sessions";
const assetUrl =
  "https://api.runevents.net/api/assets/download/SessionMaterialFile/";
const headers = { Referer: "https://summit.wpninjas.global/" };
const guidPattern =
  /^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i;

export function collectMaterials(payload) {
  if (
    !payload ||
    payload.successful === false ||
    !Array.isArray(payload.data)
  ) {
    throw new Error("Expected a successful API response with a data array.");
  }
  const files = new Map();
  const usedNames = new Set(["readme.html", "readme.md"]);
  let externalLinks = 0;
  for (const session of payload.data) {
    if (!session || !Array.isArray(session.materials)) {
      throw new Error("Each session must contain a materials array.");
    }
    for (const material of session.materials) {
      if (material?.sessionMaterialTypeId !== 1) {
        externalLinks += 1;
        continue;
      }
      if (
        !guidPattern.test(material.blobId) ||
        /^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(material.blobId) ||
        typeof material.fileName !== "string" ||
        !material.fileName.trim()
      ) {
        throw new Error(`Invalid file material in session ${session.id}.`);
      }
      const blobId = material.blobId.toLowerCase();
      if (files.has(blobId)) continue;
      const originalName = material.fileName.trim();
      const originalExtension = path.extname(originalName);
      const title =
        typeof session.title === "string" && session.title.trim()
          ? session.title.trim()
          : originalName;
      const titleStem =
        originalExtension &&
        title.toLowerCase().endsWith(originalExtension.toLowerCase())
          ? title.slice(0, -originalExtension.length)
          : title;
      const safeName =
        `${titleStem.slice(0, 140)}${originalExtension}`
          .trim()
          .replace(/(?:%[\da-f]{2}|[\s<>:"/\\|?*\x00-\x1f])+/gi, "_")
          .slice(0, 160)
          .replace(/[. ]+$/, "")
          .replace(/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?=\.|$)/i, "_$1") ||
        "material";
      const extension = path.extname(safeName);
      const stem = safeName.slice(0, safeName.length - extension.length);
      let fileName = safeName;
      let suffix = 2;
      while (usedNames.has(fileName.toLowerCase())) {
        fileName = `${stem}_${suffix}${extension}`;
        suffix += 1;
      }
      usedNames.add(fileName.toLowerCase());
      files.set(blobId, {
        blobId,
        url: `${assetUrl}${blobId}/${encodeURIComponent(material.fileName)}`,
        fileName,
      });
    }
  }
  return { files: [...files.values()], externalLinks };
}

export async function downloadFile(file, outputDirectory, fetchImpl = fetch) {
  await mkdir(outputDirectory, { recursive: true });
  const destination = path.join(outputDirectory, file.fileName);
  try {
    const existing = await stat(destination);
    if (!existing.isFile())
      throw new Error(`Destination is not a file: ${destination}`);
    if (existing.size > 0) return "skipped";
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  const temporary = `${destination}.${randomUUID()}.part`;
  const signal = AbortSignal.timeout(120_000);
  try {
    const response = await fetchImpl(file.url, { headers, signal });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`HTTP ${response.status}`);
    }
    if (!response.body) throw new Error("Response has no body.");
    if (
      /text\/html|application\/(?:problem\+)?json/i.test(
        response.headers.get("content-type") || "",
      )
    ) {
      await response.body.cancel();
      throw new Error("Received HTML or JSON instead of a file.");
    }
    await pipeline(
      Readable.fromWeb(response.body),
      createWriteStream(temporary, { flags: "wx" }),
      { signal },
    );
    if ((await stat(temporary)).size === 0)
      throw new Error("Downloaded file is empty.");
    await rename(temporary, destination);
    return "downloaded";
  } finally {
    await rm(temporary, { force: true });
  }
}

function escapeHtml(value) {
  return String(value ?? "").replace(
    /[&<>"']/g,
    (character) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[character],
  );
}

function escapeMarkdown(value) {
  return escapeHtml(value).replace(/[\\`*_{\}\[\]()#+.!|~-]/g, "\\$&");
}

function safeWebUrl(value) {
  try {
    const url = new URL(value);
    return ["https:", "http:"].includes(url.protocol) &&
      !url.username &&
      !url.password
      ? url.href
      : null;
  } catch {
    return null;
  }
}

export async function writeReadmes(payload, files, outputDirectory) {
  await mkdir(outputDirectory, { recursive: true });
  const fileByBlob = new Map();
  for (const file of files) {
    let available = false;
    try {
      const info = await stat(path.join(outputDirectory, file.fileName));
      available = info.isFile() && info.size > 0;
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    fileByBlob.set(file.blobId, { ...file, available });
  }
  const markdown = [
    "# Session Materials",
    "",
    `${payload.data.length} sessions.`,
    "",
  ];
  const sections = [];
  for (const session of payload.data) {
    const title = String(session.title || "Untitled session").replace(
      /\s+/g,
      " ",
    );
    const speakers =
      (session.speakers || [])
        .map(
          (speaker) =>
            `${speaker.name || "Unknown speaker"}${speaker.id != null ? ` (ID: ${speaker.id})` : ""}`,
        )
        .join(", ") || "Not provided";
    const topics =
      (session.labels || [])
        .map((label) => label.name)
        .filter(Boolean)
        .join(", ") || "Not provided";
    const details = [
      ["Session ID", session.id ?? "Not provided"],
      ["Speakers", speakers],
      ["Start (as supplied)", session.startDate || "Not provided"],
      ["Room", session.roomName || "Not provided"],
      ["Topics", topics],
    ];
    const abstract = session.abstract || "No abstract provided.";
    markdown.push(`## ${escapeMarkdown(title)}`, "");
    for (const [label, value] of details) {
      markdown.push(
        `**${label}:** ${escapeMarkdown(String(value).replace(/\s+/g, " "))}  `,
      );
    }
    markdown.push("", escapeMarkdown(abstract), "", "### Materials", "");
    const materialItems = [];
    for (const material of session.materials) {
      const label = String(
        material.title || material.fileName || "Material",
      ).replace(/\s+/g, " ");
      const file =
        material.sessionMaterialTypeId === 1
          ? fileByBlob.get(material.blobId?.toLowerCase())
          : null;
      let target;
      let status;
      if (file) {
        target = file.available
          ? `./${encodeURIComponent(file.fileName)}`
          : file.url;
        status = file.available
          ? `Local file: ${file.fileName}`
          : "Not downloaded; source download";
      } else {
        target = safeWebUrl(material.url);
        status = target ? "External link (not downloaded)" : "No usable link";
      }
      const description = material.description
        ? String(material.description)
        : "";
      const markdownLink = target
        ? `[${escapeMarkdown(label)}](<${target.replace(/[()]/g, (character) => (character === "(" ? "%28" : "%29"))}>)`
        : escapeMarkdown(label);
      markdown.push(`- ${markdownLink} (${escapeMarkdown(status)})`);
      if (description)
        markdown.push(
          `  ${escapeMarkdown(description).replace(/\r?\n/g, "\n  ")}`,
        );
      const htmlLink = target
        ? `<a href="${escapeHtml(target)}">${escapeHtml(label)}</a>`
        : escapeHtml(label);
      materialItems.push(
        `<li>${htmlLink} <span class="status">${escapeHtml(status)}</span>${description ? `<p class="abstract">${escapeHtml(description)}</p>` : ""}</li>`,
      );
    }
    if (!session.materials.length) markdown.push("No materials published.");
    markdown.push("");
    sections.push(`<section>
<h2>${escapeHtml(title)}</h2>
<dl>${details.map(([label, value]) => `<dt>${label}</dt><dd>${escapeHtml(value)}</dd>`).join("")}</dl>
<p class="abstract">${escapeHtml(abstract)}</p>
<h3>Materials</h3>
${materialItems.length ? `<ul>${materialItems.join("\n")}</ul>` : "<p>No materials published.</p>"}
</section>`);
  }
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Session Materials</title>
<style>
:root { color-scheme: light; }
body { margin: 0; color: #242424; background: #fafafa; font: 16px/1.6 Georgia, serif; }
main { max-width: 960px; margin: auto; padding: 24px; overflow-wrap: anywhere; }
header { border-bottom: 3px solid #087e8b; padding-bottom: 16px; }
section { border-bottom: 1px solid #ccc; padding: 24px 0; }
h1 { font-size: 32px; } h2 { font-size: 24px; } h3 { font-size: 18px; }
dl { display: grid; grid-template-columns: 160px minmax(0, 1fr); gap: 4px 16px; }
dt { font-weight: bold; } dd { margin: 0; }
a { color: #006c79; } .status { display: block; color: #555; font-size: 14px; }
.abstract { white-space: pre-wrap; } li { margin-bottom: 12px; }
@media (max-width: 560px) { dl { grid-template-columns: 1fr; } dd { margin-bottom: 8px; } main { padding: 16px; } }
</style>
</head>
<body><main><header><h1>Session Materials</h1><p>${payload.data.length} sessions</p></header>
${sections.join("\n")}
</main></body>
</html>
`;
  await writeFile(
    path.join(outputDirectory, "Readme.md"),
    markdown.join("\n"),
    "utf8",
  );
  await writeFile(path.join(outputDirectory, "Readme.html"), html, "utf8");
}

export async function main(args = process.argv.slice(2)) {
  const { values } = parseArgs({
    args,
    options: {
      input: { type: "string" },
      output: { type: "string", default: "2026" },
      fetch: { type: "boolean", default: false },
      event: { type: "string", default: "workplace-ninja-summit-2026" },
      "dry-run": { type: "boolean", default: false },
      "index-only": { type: "boolean", default: false },
      help: { type: "boolean", short: "h" },
    },
  });
  if (values.help) {
    console.log(`Usage: node cli.mjs [options]

  --input <path>    Development only: use a local JSON export instead of the API
  --output <path>   Download directory (default: 2026)
  --fetch           Fetch live metadata (already the default; optional)
  --event <slug>    API event (default: workplace-ninja-summit-2026)
  --dry-run         List file URLs without downloading
  --index-only      Write Readme.html and Readme.md without downloading
  -h, --help        Show help

Paths are relative to the current working directory.
All modes fetch live metadata unless --input is explicitly supplied for development.
External link materials are skipped; existing nonempty files are kept.
Readme.html and Readme.md are refreshed in the output directory after downloads.`);
    return;
  }
  if (
    values.fetch &&
    args.some(
      (argument) => argument === "--input" || argument.startsWith("--input="),
    )
  ) {
    throw new Error("Use either --fetch or --input, not both.");
  }
  let payload;
  if (values.input === undefined) {
    const url = new URL(apiUrl);
    url.searchParams.set("eventSlug", values.event);
    const response = await fetch(url, {
      headers: {
        ...headers,
        accept: "application/json, text/plain, */*",
        "accept-language": "en-US,en;q=0.6",
      },
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`Session API returned HTTP ${response.status}.`);
    }
    payload = await response.json();
  } else {
    payload = JSON.parse(
      (await readFile(values.input, "utf8")).replace(/^\uFEFF/, ""),
    );
  }
  const { files, externalLinks } = collectMaterials(payload);
  const outputDirectory = path.resolve(values.output);
  console.log(
    `Found ${files.length} unique files; skipping ${externalLinks} external/link materials.`,
  );
  console.log(`Output: ${outputDirectory}`);
  if (values["dry-run"]) {
    for (const file of files) console.log(file.url);
    return;
  }
  const counts = { downloaded: 0, skipped: 0, failed: 0 };
  for (const file of values["index-only"] ? [] : files) {
    try {
      const result = await downloadFile(file, outputDirectory);
      counts[result] += 1;
      console.log(`${result}: ${file.fileName}`);
    } catch (error) {
      counts.failed += 1;
      console.error(`failed: ${file.fileName}: ${error.message}`);
    }
  }
  await writeReadmes(payload, files, outputDirectory);
  console.log("Updated Readme.html and Readme.md.");
  console.log(
    `Done: ${counts.downloaded} downloaded, ${counts.skipped} skipped, ${counts.failed} failed.`,
  );
  if (counts.failed > 0) process.exitCode = 1;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  main().catch((error) => {
    console.error(`Error: ${error.message}`);
    process.exitCode = 1;
  });
}
