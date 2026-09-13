# ============================================================
# INFHUB InspIRCd Docker Image
# ============================================================
# Builds a minimal container for InspIRCd 4.x.
#
# Usage:
#   Place the InspIRCd binary as inspircd/ (next to this Dockerfile)
#   Build via docker-compose (see docker-compose.yml)
#
# Notes:
#   - Config and data are mounted as volumes (not baked into image)
#   - The binary is copied into the image for portability
#   - Runtime dependencies (libssl, etc.) are installed at build time
# ============================================================

FROM debian:bookworm-slim

# Install runtime dependencies for InspIRCd 4.x
RUN apt-get update && apt-get install -y \
    libssl3 \
    libstdc++6 \
    libgcc-s1 \
    ca-certificates \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create inspircd user and directory structure
RUN useradd -r -s /bin/false inspircd && \
    mkdir -p /home/inspircd/inspircd/run/conf && \
    mkdir -p /home/inspircd/inspircd/data && \
    mkdir -p /home/inspircd/inspircd/modules && \
    mkdir -p /home/inspircd/inspircd/logs && \
    chown -R inspircd:inspircd /home/inspircd

# Copy InspIRCd binary from build context
# User must place the InspIRCd binary at inspircd/inspircd before building
COPY inspircd /home/inspircd/inspircd/inspircd

# Copy modules (shared libraries) if present in build context
# Only copy .so files to avoid unnecessary build artifacts
RUN if [ -d modules ]; then cp modules/*.so /home/inspircd/inspircd/modules/ 2>/dev/null || true; fi

# Set permissions
RUN chmod +x /home/inspircd/inspircd/inspircd && \
    chown -R inspircd:inspircd /home/inspircd/inspircd

# Expose IRC ports (plaintext and TLS)
EXPOSE 6667 6697

# Set working directory
WORKDIR /home/inspircd/inspircd

# Run as non-root user
USER inspircd

# Health check: verify IRC port is listening
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD nc -z localhost 6667 || exit 1

# Entrypoint: run InspIRCd in foreground for Docker logging
ENTRYPOINT ["/home/inspircd/inspircd/inspircd"]
CMD ["--nofork"]
