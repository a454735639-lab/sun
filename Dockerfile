# ===================== build stage =====================
# Builds the sun-panel Go server and the Vue web frontend from source.
#
# Why this file exists: the tar this package was extracted from is not source
# code. It is a Docker image containing only the already-compiled server, the
# built web frontend and a config file. Rebuilding from the upstream repository
# is the only way to get a working app for other architectures.
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache git nodejs npm

WORKDIR /src

# --- backend (Go server) ---
# Upstream source. Sun-panel's releases are tagged v1.8.1, v2.0.2-beta… (checked
# against the repository's tag list). Override with --build-arg to build another.
# - If SUN_PANEL_REF is empty, the default branch is used.
ARG SUN_PANEL_REF=v1.8.1
RUN if [ -n "${SUN_PANEL_REF}" ]; then \
        git clone --depth 1 --branch "${SUN_PANEL_REF}" https://github.com/hslr-s/sun-panel.git . ; \
    else \
        git clone --depth 1 https://github.com/hslr-s/sun-panel.git . ; \
    fi

# Cross-compile for the image's own platform, not the build machine's.
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags "-s -w" -o /out/sun-panel .

# --- frontend (Vue web) ---
WORKDIR /src/web
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
RUN npm run build
# Vite writes to web/dist; if a release tars an already-built folder, keep that.
RUN if [ -d /src/web/dist ]; then cp -r /src/web/dist /out/web ; \
    else cp -r /src/web /out/web ; fi

# ===================== runtime stage =====================
# Mirrors the original image: Alpine, /app workdir, port 3002.
FROM alpine:3.20

RUN apk add --no-cache bash ca-certificates tzdata

WORKDIR /app

COPY --from=builder /out/web /app/web
COPY --from=builder /out/sun-panel /app/sun-panel
COPY conf/conf.ini /app/conf/conf.ini
COPY conf/conf.example.ini /app/conf/conf.example.ini

RUN chmod +x /app/sun-panel

# The server writes conf.ini and creates database.db on first start, so do NOT
# try to run it here: this build may be cross-compiling for another CPU and the
# binary would not be executable on the build machine.
RUN mkdir -p /app/conf/database /app/conf/uploads /app/runtime/temp /app/runtime/runlog

EXPOSE 3002

CMD ["/bin/sh", "-c", "./sun-panel"]
