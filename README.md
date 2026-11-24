# sun-panel — rebuilt source package

This folder is a GitHub-ready package extracted from the `hslr/sun-panel:latest`
container image. It contains everything the image ships so you can rebuild the
image yourself.

## What's in here

| Path | What it is |
|------|------------|
| `Dockerfile` | Rebuilds the whole image (backend + frontend) from upstream source |
| `.dockerignore` | Keeps local runtime/data files out of the build |
| `build/sun-panel` | The compiled ARM64 server binary pulled out of the image (reference; see note below) |
| `web/` | The built web frontend (Vue) served by the server |
| `conf/conf.ini` | The default config the server generates on first run |
| `conf/conf.example.ini` | Same config, kept as an example |

> `build/sun-panel` is a 33 MB Linux ARM64 executable. It is **not committed to
> this repository** — `.gitignore` excludes it, because it is a large binary blob
> that `docker build` never uses (the Dockerfile compiles its own binary from
> upstream source). If you have a local copy of the package folder, the file is
> there; on GitHub it will be absent, and that is expected.

## What sun-panel is

A self-hosted server / navigation panel. The original image is
`docker.io/hslr/sun-panel:latest` — an Alpine image (arm64) that runs the Go
server binary from `/app` and listens on port **3002**.

## Build the image

```bash
docker build -t sun-panel:local .
```

The Dockerfile clones the upstream source (pinned by `SUN_PANEL_REF`, default
`v1.8.1`), compiles the Go server for your target architecture, builds the Vue
frontend, and copies both into a fresh Alpine image — the same layout the
original uses.

To build for a different CPU (e.g. an amd64 host from an arm64 machine):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t sun-panel:local .
```

## Run it

```bash
docker run -d --name sun-panel -p 3002:3002 \
  -v ./conf:/app/conf -v ./runtime:/app/runtime \
  sun-panel:local
```

Then open <http://localhost:3002>.

## Configuration

Edit `conf/conf.ini`:

- `http_port` — web port (default `3002`)
- `database_drive` — `sqlite` (default) or `mysql`
- `web_path` — where the frontend lives (`./web`)
- `[cert]` — fill `cert_path` / `key_path` to enable HTTPS on port `3003`

Data (database, uploads, logs) lives under `conf/` and `runtime/`; mount those
as volumes so it survives rebuilds.

## Notes

- The Go server and the web frontend are **compiled/minified** in the image, so
  they're shipped here as-is; the Dockerfile rebuilds them from the real
  upstream source.
- `build/sun-panel` is the arm64 binary from the image — it's included for
  reference only. The Dockerfile produces its own binary and doesn't use it.
- **Only arm64 is shipped.** The binary in the tar is a Linux ARM64 executable,
  so `docker build` (which rebuilds from source) is how you get amd64.

## What was verified, and what wasn't

| Item | Status |
|---|---|
| `SUN_PANEL_REF=v1.8.1` is a real tag upstream | Checked against the repository's tag list (`git ls-remote`) |
| Package contents complete | `python verify.py` → `PACKAGE COMPLETE` (all files, 48 web files) |
| Server defaults in `conf/conf.ini` | Read directly from the file in the image |
| Behaviour of the server (ports, login, hashing) | Recovered from the compiled binary; the addresses and the rules are written up in the viewer's `MECHANICS.md`, kept outside this repository |
| `docker build -t sun-panel:local .` | **NOT RUN** — no Docker on the machine this was assembled on |

The Dockerfile has never been executed, so treat the build as unproven until
your first `docker build` finishes. If it fails, the message will point at one
of three things: the tag (`SUN_PANEL_REF`), the Go build path, or the frontend
build script.

