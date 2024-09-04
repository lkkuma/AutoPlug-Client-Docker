### Set global arguments with defaults
ARG JAVA_VERSION="21"

# Set AutoPlug Client download values
ARG AP_CLIENT_BUILD="stable"
ARG AP_CLIENT_DOWNLOAD="https://github.com/Osiris-Team/AutoPlug-Releases/raw/master/${AP_CLIENT_BUILD}-builds/AutoPlug-Client.jar"

###         < == RUNTIME == >
# From Eclipse Adoptium Temurin JRE
FROM eclipse-temurin:${JAVA_VERSION}-jre

# Install needed packages
RUN apt-get update && apt-get install -y --no-install-recommends curl=\*

# Create base directories
WORKDIR /app
RUN mkdir autoplug mods plugins

COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

# Install needed packages before clearing the cache
RUN apt-get update && apt-get install -y --no-install-recommends \
    git=\*\
    dumb-init=\*\
    adduser=\*\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set and mount working directory
WORKDIR /app
VOLUME /app

# Download latest AutoPlug-Client
ARG AP_CLIENT_DOWNLOAD
RUN curl -o AutoPlug-Client.jar -L ${AP_CLIENT_DOWNLOAD}

# Create and set autoplug user and group
RUN adduser --system --home /home/autoplug --group --uid 10000 autoplug
RUN chown -R autoplug:autoplug /app

USER autoplug:autoplug

# Expose default Minecraft port to host
EXPOSE 25565:25565/tcp
EXPOSE 25565:25565/udp

ENV TITLE="AutoPlug for Docker"
ENV MAINTAINER="https://github.com/lkkuma"
ENV URL="https://hub.docker.com/r/lkkuma/autoplug-client"
ENV SOURCE="https://github.com/lkkuma/AutoPlug-Client-Docker"
ENV AP_AUTHOR="OsirisTeam"
ENV AP_URL="https://autoplug.one"

# Set image metadata labels
LABEL "org.opencontainers.image.title"=${TITLE} \
      "org.opencontainers.image.authors"=${MAINTAINER} \
      "org.opencontainers.image.url"=${URL} \
      "org.opencontainers.image.source"=${SOURCE}
LABEL "one.autoplug.author"=${AP_AUTHOR} \
      "one.autoplug.url"=${AP_URL}

# Set image entrypoint
ENTRYPOINT ["dumb-init","/app/entrypoint.sh"]