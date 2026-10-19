FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends python3 ca-certificates curl unzip libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libpulse0 && rm -rf /var/lib/apt/lists/*
ARG TARGETARCH
RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      amd64) godot_arch=x86_64; godot_sha=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4 ;; \
      arm64) godot_arch=arm64; godot_sha=5dd0d86405cf7e8adf79fb6377b38ba682a2846cb378ffe5364f38c01ad29b9d ;; \
      *) echo 'Unsupported Godot architecture' >&2; exit 1 ;; \
    esac \
 && curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.${godot_arch}.zip" -o /tmp/godot.zip \
 && echo "${godot_sha}  /tmp/godot.zip" | sha256sum -c - \
 && unzip /tmp/godot.zip -d /tmp/godot \
 && mv "/tmp/godot/Godot_v4.7.2-stable_linux.${godot_arch}" /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot && rm -rf /tmp/godot /tmp/godot.zip
WORKDIR /app
COPY project.godot main.tscn icon.svg default_bus_layout.tres ./
COPY scripts ./scripts
COPY assets ./assets
COPY scenes ./scenes
COPY resources ./resources
COPY cloudflare/server.py ./server.py
RUN godot --headless --path /app --import
ENV PORT=9080
ENV HOME=/tmp
USER 10001:10001
EXPOSE 8080
CMD ["python3", "server.py"]
