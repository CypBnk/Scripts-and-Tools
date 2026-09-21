import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { collectMaterials, downloadFile, writeReadmes, main } from "./cli.mjs";

const blobId = "102b6a5b-b295-4927-93c5-fb8d58dfd1d2";
const material = {
  blobId,
  fileName: "wpninja_summit_somesh_Houston_migration.pdf",
  sessionMaterialTypeId: 1,
};
const payload = (materials, title) => ({
  successful: true,
  data: [{ id: 1, title, materials }],
});

test("builds the supplied URL, deduplicates files, and skips link materials", () => {
  const result = collectMaterials(
    payload([
      material,
      material,
      { sessionMaterialTypeId: 2, url: "https://example.com" },
    ]),
  );
  assert.equal(result.files.length, 1);
  assert.equal(result.files[0].fileName, material.fileName);
  assert.equal(result.externalLinks, 1);
  assert.equal(
    result.files[0].url,
    `https://api.runevents.net/api/assets/download/SessionMaterialFile/${blobId}/${material.fileName}`,
  );
  assert.equal(collectMaterials(payload([])).files.length, 0);
});

test("encodes URL filenames and keeps output names inside the destination", () => {
  const fileName = "../Slides / a?#%.pdf";
  const [file] = collectMaterials(payload([{ ...material, fileName }])).files;
  assert.ok(file.url.endsWith(encodeURIComponent(fileName)));
  assert.equal(path.basename(file.fileName), file.fileName);
  assert.ok(!/[<>:"/\\|?*]/.test(file.fileName));
});

test("normalizes whitespace and percent escapes in saved names without changing URLs", () => {
  for (const [fileName, expected] of [
    [" My Slides.pdf ", "My_Slides.pdf"],
    ["My%20Slides.pdf", "My_Slides.pdf"],
    ["My%20%20Slides\t2026.pdf", "My_Slides_2026.pdf"],
    ["Slides%2fPart%3AOne.pdf", "Slides_Part_One.pdf"],
    ["100% complete.pdf", "100%_complete.pdf"],
  ]) {
    const [file] = collectMaterials(payload([{ ...material, fileName }])).files;
    assert.equal(file.fileName, expected);
    assert.equal(
      file.url,
      `https://api.runevents.net/api/assets/download/SessionMaterialFile/${blobId}/${encodeURIComponent(fileName)}`,
    );
  }
});

test("adds numeric suffixes for filename collisions while deduplicating blobs", () => {
  const names = [
    "My Slides.pdf",
    "My_Slides_2.pdf",
    "My%20Slides.pdf",
    "my_slides.PDF",
  ];
  const materials = names.map((fileName, index) => ({
    ...material,
    fileName,
    blobId: `102b6a5b-b295-4927-93c5-${String(index).padStart(12, "0")}`,
  }));
  const { files } = collectMaterials(payload([materials[0], ...materials]));
  assert.deepEqual(
    files.map((file) => file.fileName),
    ["My_Slides.pdf", "My_Slides_2.pdf", "My_Slides_3.pdf", "my_slides_4.PDF"],
  );
});

test("protects Windows reserved filenames without a GUID prefix", () => {
  for (const [fileName, expected] of [
    ["CON.pdf", "_CON.pdf"],
    ["nul", "_nul"],
    ["LPT1.pptx", "_LPT1.pptx"],
    ["...", "material"],
  ]) {
    const [file] = collectMaterials(payload([{ ...material, fileName }])).files;
    assert.equal(file.fileName, expected);
  }
});

test("uses session titles instead of material titles and reserves index filenames", () => {
  for (const [title, expected] of [
    ["Session Slides", "Session_Slides.pdf"],
    ["Session Slides.PDF", "Session_Slides.pdf"],
    ["Version 1.0", "Version_1.0.pdf"],
    ["CON", "_CON.pdf"],
    ["A".repeat(200), `${"A".repeat(140)}.pdf`],
    [" ", material.fileName],
    [
      "Edge Management Service: Multi platform Edge management",
      "Edge_Management_Service_Multi_platform_Edge_management.pdf",
    ],
  ]) {
    const [file] = collectMaterials(
      payload([{ ...material, title: "Presentation" }], title),
    ).files;
    assert.equal(file.fileName, expected);
    assert.ok(file.url.endsWith(material.fileName));
  }
  const { files } = collectMaterials(
    payload(
      [
        { ...material, title: "Readme", fileName: "original.html" },
        {
          ...material,
          blobId: "102b6a5b-b295-4927-93c5-fb8d58dfd1d3",
          title: "Readme",
          fileName: "original.md",
        },
      ],
      "Readme",
    ),
  );
  assert.deepEqual(
    files.map((file) => file.fileName),
    ["Readme_2.html", "Readme_2.md"],
  );
});

test("rejects malformed metadata and failed API responses", () => {
  for (const invalid of [
    null,
    {},
    { successful: false, data: [] },
    { data: [null] },
    payload([{ ...material, blobId: "../bad" }]),
  ]) {
    assert.throws(() => collectMaterials(invalid));
  }
});

test("streams files, skips completed files, and replaces empty files", async (context) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "ninja-test-"));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const [file] = collectMaterials(payload([material])).files;
  const target = path.join(directory, file.fileName);
  await writeFile(target, "");
  const fetchImpl = async (url, options) => {
    assert.equal(url, file.url);
    assert.equal(options.headers.Referer, "https://summit.wpninjas.global/");
    assert.ok(options.signal instanceof AbortSignal);
    return new Response("%PDF-test", {
      headers: { "content-type": "application/pdf" },
    });
  };
  assert.equal(await downloadFile(file, directory, fetchImpl), "downloaded");
  assert.equal(await readFile(target, "utf8"), "%PDF-test");
  assert.equal(
    await downloadFile(file, directory, () =>
      assert.fail("Must not fetch existing file"),
    ),
    "skipped",
  );
  assert.deepEqual(await readdir(directory), [file.fileName]);
});

test("HTTP, HTML, empty body, and interrupted streams leave no completed or partial file", async (context) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "ninja-test-"));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const [file] = collectMaterials(payload([material])).files;
  const responses = [
    () => new Response("Denied", { status: 403 }),
    () =>
      new Response("<html>Login</html>", {
        headers: { "content-type": "text/html" },
      }),
    () => new Response(""),
    () =>
      new Response(
        new ReadableStream({
          start(controller) {
            controller.enqueue(new Uint8Array([1, 2, 3]));
          },
          pull(controller) {
            controller.error(new Error("Connection lost"));
          },
        }),
      ),
  ];
  for (const response of responses) {
    await assert.rejects(downloadFile(file, directory, async () => response()));
    assert.deepEqual(await readdir(directory), []);
  }
});

test("indexes all sessions, speakers, local files, missing files, and safe external links", async (context) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "ninja-index-"));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const data = {
    data: [
      {
        id: 1,
        title: "Session <script>alert</script>",
        abstract: "First paragraph\n\nSecond paragraph",
        startDate: "2026-09-14T13:40:00",
        roomName: "Main & Hall",
        speakers: [
          { id: 10, name: "Speaker One" },
          { id: 11, name: "Speaker Two" },
        ],
        labels: [{ name: "Security" }],
        materials: [
          { ...material, title: "Slides", description: "Deck <img src=x>" },
          {
            ...material,
            blobId: "102b6a5b-b295-4927-93c5-fb8d58dfd1d3",
            title: "Slides",
          },
          {
            sessionMaterialTypeId: 2,
            title: "Website",
            url: "https://example.com/?a=1&b=2",
          },
          {
            sessionMaterialTypeId: 2,
            title: "Unsafe",
            url: "javascript:alert(1)",
          },
        ],
      },
      { id: 2, title: "No slides session", materials: [] },
      {
        id: 3,
        title: "Shared material",
        materials: [{ ...material, title: "Slides" }],
      },
    ],
  };
  const { files } = collectMaterials(data);
  assert.deepEqual(
    files.map((file) => file.fileName),
    ["Session_script_alert_script_.pdf", "Session_script_alert_script__2.pdf"],
  );
  await writeFile(path.join(directory, files[0].fileName), "%PDF-test");
  await writeReadmes(data, files, directory);
  const html = await readFile(path.join(directory, "Readme.html"), "utf8");
  const markdown = await readFile(path.join(directory, "Readme.md"), "utf8");
  for (const content of [html, markdown]) {
    for (const text of [
      "Session",
      "Speaker One",
      "Speaker Two",
      "Security",
      "2026-09-14T13:40:00",
      "No slides session",
      "No materials published.",
      "First paragraph",
      "Second paragraph",
      "Not downloaded; source download",
      "No usable link",
    ]) {
      assert.ok(content.replace(/\\([^\w\s])/g, "$1").includes(text), text);
    }
    assert.ok(!content.includes("<script>"));
    assert.ok(!content.includes("<img src=x>"));
    assert.ok(!content.includes("javascript:"));
    assert.ok(content.includes(files[1].url));
  }
  assert.equal(html.split(`href="./${files[0].fileName}"`).length - 1, 2);
  assert.ok(!html.includes(`href="./${files[1].fileName}"`));
  assert.ok(markdown.includes(`[Slides](<./${files[0].fileName}>)`));
  assert.ok(html.includes("Main &amp; Hall"));
  assert.ok(html.includes("Speaker One (ID: 10)"));
  await writeReadmes({ data: [] }, [], directory);
  assert.ok(
    !(await readFile(path.join(directory, "Readme.html"), "utf8")).includes(
      "Speaker One",
    ),
  );
});

test("all CLI modes fetch live metadata by default and honor the event option", async (context) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "ninja-live-"));
  context.after(() => rm(directory, { recursive: true, force: true }));
  context.mock.method(console, "log", () => {});
  const requests = [];
  context.mock.method(globalThis, "fetch", async (url, options) => {
    requests.push({ url: new URL(url), options });
    return Response.json({ successful: true, data: [] });
  });
  for (const mode of [[], ["--index-only"], ["--dry-run"], ["--fetch"]]) {
    await main([...mode, "--output", directory]);
  }
  await main(["--dry-run", "--event", "another-event"]);
  assert.equal(requests.length, 5);
  for (const request of requests) {
    assert.equal(request.url.origin, "https://api.runevents.net");
    assert.equal(
      request.url.pathname,
      "/api/sessions-and-speakers/external-sessions",
    );
    assert.equal(
      request.options.headers.Referer,
      "https://summit.wpninjas.global/",
    );
  }
  assert.equal(
    requests[0].url.searchParams.get("eventSlug"),
    "workplace-ninja-summit-2026",
  );
  assert.equal(requests[4].url.searchParams.get("eventSlug"), "another-event");
});

test("local metadata requires an explicit development input override", async (context) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "ninja-input-"));
  context.after(() => rm(directory, { recursive: true, force: true }));
  context.mock.method(console, "log", () => {});
  context.mock.method(globalThis, "fetch", () =>
    assert.fail("Development input must not fetch"),
  );
  const input = path.join(directory, "fixture.json");
  await writeFile(input, JSON.stringify(payload([])));
  await main(["--input", input, "--dry-run"]);
  await assert.rejects(
    main(["--fetch", "--input", input, "--dry-run"]),
    /not both/,
  );
  assert.deepEqual(await readdir(directory), ["fixture.json"]);
});

test("live API failures do not fall back to the development export", async (context) => {
  context.mock.method(
    globalThis,
    "fetch",
    async () => new Response("Unavailable", { status: 503 }),
  );
  await assert.rejects(main(["--dry-run"]), /Session API returned HTTP 503/);
});

test("parses the workspace export and includes the example material", async () => {
  const data = JSON.parse(
    await readFile(new URL("./data.json", import.meta.url), "utf8"),
  );
  const { files } = collectMaterials(data);
  assert.ok(
    files.some((file) => file.url.endsWith(`/${blobId}/${material.fileName}`)),
  );
  assert.equal(
    new Set(files.map((file) => file.fileName.toLowerCase())).size,
    files.length,
  );
});
