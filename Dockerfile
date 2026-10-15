FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends python3 ca-certificates curl unzip libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libpulse0 && rm -rf /var/lib/apt/lists/*
RUN curl -fL https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip -o /tmp/godot.zip \
 && echo 'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4  /tmp/godot.zip' | sha256sum -c - \
 && unzip /tmp/godot.zip -d /tmp/godot \
 && mv /tmp/godot/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot && rm -rf /tmp/godot /tmp/godot.zip
WORKDIR /app
COPY project.godot main.tscn icon.svg ./
COPY scripts ./scripts
COPY assets ./assets
COPY cloudflare/server.py ./server.py
RUN godot --headless --path /app --import
ENV PORT=9080
ENV HOME=/tmp
USER 10001:10001
EXPOSE 8080
CMD ["python3", "server.py"]
