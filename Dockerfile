# Luanti Server Dockerfile (Updated December 2025)
# Use Alpine as base image for the builder stage
FROM alpine:latest AS builder

# Enable community repository and install required dependencies
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
    build-base \
    cmake \
    git \
    sqlite-dev \
    bzip2-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    gmp-dev \
    curl-dev \
    openssl-dev \
    zlib-dev \
    wget \
    unzip

# Build LuaJIT from source (OpenResty fork with PRNG fixes for Mineclonia compatibility)
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/openresty/luajit2.git && \
    cd luajit2 && \
    make -j$(nproc) && \
    make install PREFIX=/usr/local && \
    rm -rf /tmp/luajit2 && \
    ls -la /usr/local/bin/luajit*

# Clone Luanti (formerly Minetest) from the new official repository
WORKDIR /luanti/
RUN git clone https://github.com/luanti-org/luanti.git --depth 1
WORKDIR /luanti/luanti

# Build Luanti (server only) - point to custom LuaJIT
RUN cmake . \
    -DRUN_IN_PLACE=TRUE \
    -DBUILD_SERVER=TRUE \
    -DBUILD_CLIENT=FALSE \
    -DENABLE_GETTEXT=FALSE \
    -DENABLE_FREETYPE=FALSE \
    -DENABLE_LEVELDB=FALSE \
    -DENABLE_SYSTEM_JSONCPP=FALSE \
    -DENABLE_SPATIAL=FALSE \
    -DENABLE_CURL=FALSE \
    -DENABLE_SOUND=FALSE \
    -DENABLE_LUAJIT=TRUE \
    -DENABLE_SYSTEM_GMP=TRUE \
    -DLUAJIT_INCLUDE_DIR=/usr/local/include/luajit-2.1 \
    -DLUAJIT_LIBRARY=/usr/local/lib/libluajit-5.1.so
RUN make -j$(nproc)
RUN make install

# Clone game repositories
WORKDIR /luanti/luanti/games

# Mineclonia - actively maintained (v0.118.1+)
RUN git clone https://codeberg.org/mineclonia/mineclonia --depth 1 && \
    rm -rf mineclonia/.git

# VoxeLibre - actively maintained
RUN git clone https://git.minetest.land/VoxeLibre/VoxeLibre --depth 1 && \
    mv VoxeLibre voxelibre && \
    rm -rf voxelibre/.git

# Note: minetest_game is deprecated and no longer actively maintained
# Uncomment below if you still need it:
# RUN git clone https://github.com/luanti-org/minetest_game --depth 1 && \
#     rm -rf minetest_game/.git

# Download and install mods
WORKDIR /luanti/luanti/mods

# spectator_mode - stable mod for spectating players
RUN git clone https://github.com/minetest-mods/spectator_mode --depth 1 && \
    rm -rf spectator_mode/.git

# Animalia - fauna mod (somewhat dormant but functional)
RUN wget https://github.com/ElCeejo/animalia/archive/refs/heads/main.zip -O animalia.zip && \
    unzip animalia.zip && \
    mv animalia-main animalia && \
    rm animalia.zip

# i3 - inventory mod (actively maintained)
RUN wget https://github.com/mt-historical/i3/archive/refs/heads/main.zip -O i3.zip && \
    unzip i3.zip && \
    mv i3-main i3 && \
    rm i3.zip

# 3D Armor - armor system mod (actively maintained)
RUN wget https://github.com/minetest-mods/3d_armor/archive/refs/heads/master.zip -O 3d_armor.zip && \
    unzip 3d_armor.zip && \
    mv 3d_armor-master 3d_armor && \
    rm 3d_armor.zip

# Download and install texture packs
WORKDIR /luanti/luanti/textures

# Soothing 32 - nice 32x texture pack
RUN wget https://gitlab.com/zughy-friends-minetest/soothing-32/-/archive/master/soothing-32-master.zip -O soothing_32.zip && \
    unzip soothing_32.zip && \
    mv soothing-32-master soothing_32 && \
    rm soothing_32.zip

# RPG 16 - Note: no longer actively supported but still functional
RUN wget https://codeberg.org/HuguesRoss/rpg16/archive/master.zip -O rpg16.zip && \
    unzip rpg16.zip && \
    rm rpg16.zip

# Less Dirt - texture adjustments (inactive since 2022 but functional)
RUN wget https://github.com/Treer/LessDirt/archive/refs/heads/master.zip -O less_dirt.zip && \
    unzip less_dirt.zip && \
    mv LessDirt-master less_dirt && \
    rm less_dirt.zip

# Create config directory
RUN mkdir -p /luanti/luanti/config

# Clean up build dependencies to reduce image size
RUN apk del build-base cmake git wget unzip && \
    rm -rf /var/cache/apk/*

# Use a minimal runtime image with C++ runtime and SQLite
FROM alpine:latest

# Install C++ runtime, SQLite, and other runtime dependencies (no luajit - we use custom build)
RUN apk update && \
    apk add --no-cache \
    libstdc++ \
    sqlite \
    sqlite-dev \
    libpng \
    libjpeg-turbo \
    gmp \
    curl \
    openssl \
    zlib \
    libgcc

# Copy custom LuaJIT from builder stage
COPY --from=builder /usr/local/lib/libluajit-5.1.so* /usr/local/lib/
COPY --from=builder /usr/local/bin/luajit /usr/local/bin/luajit
RUN ldconfig /usr/local/lib || true

# Copy only the necessary files from the builder stage
COPY --from=builder /luanti /luanti

# Create directories for games, mods, textures, and worlds
RUN mkdir -p /luanti/luanti/games && \
    mkdir -p /luanti/luanti/mods && \
    mkdir -p /luanti/luanti/textures && \
    mkdir -p /luanti/luanti/worlds/world

# Expose ports
EXPOSE 30000-30001

# Copy start script and set permissions
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
