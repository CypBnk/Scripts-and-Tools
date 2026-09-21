# NinjaScraper

Node.js CLI for downloading run.events session material files to `2026` by default.
Requires Node.js 22 or newer. No dependencies or installation step needed.

Run these commands from this directory.

## Download

Fetch current metadata from the Workplace Ninja Summit 2026 API and download:

```sh
npm start
```

All modes fetch live metadata by default. `data.json` is a development fixture only.
The optional `--fetch` flag is still supported but is no longer needed.

Preview download URLs without writing files:

```sh
npm start -- --dry-run
```

Generate or refresh `2026/Readme.html` and `2026/Readme.md` from live metadata without downloading:

```sh
npm start -- --index-only
```

Both indexes are also refreshed after every download run, even when some downloads fail.
They cover all sessions with abstracts, speaker names and IDs, start times as supplied,
rooms, topics, material descriptions, and links. Existing nonempty files get local links;
missing files get source download links. External HTTP(S) links are listed but not downloaded.
Speaker biographies are not present in the source export. `--dry-run` writes no indexes.

Choose a different output directory or event, or explicitly use a local development fixture:

```sh
node cli.mjs --output ./Download
node cli.mjs --event workplace-ninja-summit-2026
node cli.mjs --input data.json --dry-run
node cli.mjs --help
```

Paths are relative to the current working directory. Live requests never overwrite
the local JSON or fall back to it on failure. `--input` is for development only and
cannot be combined with `--fetch`.

## Behavior

- Downloads type-1 file materials using `blobId` and the URL-encoded `fileName`.
- Deduplicates by blob ID; saves cleaned session titles (`data[].title`) without GUID prefixes, retaining the original file extension. Blank session titles fall back to the original filename. Material titles remain the link labels in the indexes.
- Adds numeric suffixes (`_2`, `_3`, etc.) before the extension for duplicate names within the metadata, ignoring case.
- Sanitizes filenames for Windows and limits their length.
- Replaces whitespace and percent-encoded sequences such as `%20` with `_` in saved filenames; download URLs retain their original encoding.
- Skips external/link materials (type 2), including sharing pages and website links.
- Keeps existing nonempty files; delete a file to download it again.
- Streams sequential downloads to temporary files, then renames completed files.
- Rejects HTTP errors, HTML/JSON responses, and empty files; removes temporary files on handled failures.
- Uses a 30-second metadata timeout and a 120-second timeout per download.
- Continues after individual failures, prints a summary, and exits with code 1 if any fail.

Rerun the same command to retry failed downloads. Completed files are skipped.
Previously downloaded files using the old naming convention are not renamed and will
not be recognized under their new title-based names.
A forcefully terminated process may leave `.part` files, which can be deleted;
they are never treated as completed downloads. Existing files are not checksum-verified.

## Tests

```sh
npm test
```

Tests use local fixtures and simulated download responses; no network required.
