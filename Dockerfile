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
    luajit-dev \
    wget \
    unzip

# Clone Minetest
WORKDIR /minetest/
RUN git clone https://github.com/minetest/minetest.git --depth 1
WORKDIR /minetest/minetest

# Build Minetest (server only)
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
    -DENABLE_SYSTEM_GMP=TRUE
RUN make -j$(nproc)
RUN make install

# Clone game repositories
WORKDIR /minetest/minetest/games
RUN git clone https://codeberg.org/mineclonia/mineclonia --depth 1 && \
    rm -rf mineclonia/.git
RUN git clone https://git.minetest.land/VoxeLibre/VoxeLibre --depth 1 && \
    mv VoxeLibre voxelibre && \
    rm -rf voxelibre/.git
RUN git clone https://github.com/minetest/minetest_game --depth 1 && \
    rm -rf minetest_game/.git

# Download and install specified mods
WORKDIR /minetest/minetest/mods

# spectator_mode
RUN git clone https://github.com/minetest-mods/spectator_mode --depth 1 && \
    rm -rf spectator_mode/.git

# Animalia (from GitHub)
RUN wget https://github.com/ElCeejo/animalia/archive/refs/heads/main.zip -O animalia.zip && \
    unzip animalia.zip && \
    mv animalia-main animalia && \
    rm animalia.zip

# i3 (from GitHub)
RUN wget https://github.com/mt-historical/i3/archive/refs/heads/main.zip -O i3.zip && \
    unzip i3.zip && \
    mv i3-main i3 && \
    rm i3.zip

# 3D Armour (from GitHub)
RUN wget https://github.com/minetest-mods/3d_armor/archive/refs/heads/master.zip -O 3d_armor.zip && \
    unzip 3d_armor.zip && \
    mv 3d_armor-master 3d_armor && \
    rm 3d_armor.zip

# Download and install specified texture packs
WORKDIR /minetest/minetest/textures

# Soothing 32 (from GitLab)
RUN wget https://gitlab.com/zughy-friends-minetest/soothing-32/-/archive/master/soothing-32-master.zip -O soothing_32.zip && \
    unzip soothing_32.zip && \
    mv soothing-32-master soothing_32 && \
    rm soothing_32.zip

# RPG 16 (from Codeberg)
RUN wget https://codeberg.org/HuguesRoss/rpg16/archive/master.zip -O rpg16.zip && \
    unzip rpg16.zip && \
    rm rpg16.zip

# Less Dirt (from GitHub)
RUN wget https://github.com/Treer/LessDirt/archive/refs/heads/master.zip -O less_dirt.zip && \
    unzip less_dirt.zip && \
    mv LessDirt-master less_dirt && \
    rm less_dirt.zip

# Create config directory
RUN mkdir -p /minetest/minetest/config

# Clean up build dependencies to reduce image size
RUN apk del build-base cmake git wget unzip && \
    rm -rf /var/cache/apk/*

# Use a minimal runtime image with C++ runtime and SQLite
FROM alpine:latest

# Install C++ runtime, SQLite, and other runtime dependencies
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
    luajit

# Copy only the necessary files from the builder stage
COPY --from=builder /minetest /minetest

# Create directories for games, mods, and textures
RUN mkdir -p /minetest/minetest/games
RUN mkdir -p /minetest/minetest/mods
RUN mkdir -p /minetest/minetest/textures
RUN mkdir -p /minetest/minetest/worlds/world

# Expose ports
EXPOSE 30000-30001

# Copy start script and set permissions
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
