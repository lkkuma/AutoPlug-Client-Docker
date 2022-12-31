# Set global arguments with defaults
ARG JAVA_VERSION    17
ARG XMS             4G 
ARG XMX             4G
ARG PROXY_SERVER    0

# Set global arguments
ARG TARGET_SOFTWARE
ARG START_ON_BOOT
ARG START_COMMAND
ARG AP_WEB_KEY

ARG AP_JAVA_UPDATER_ENABLED
ARG AP_JAVA_UPDATER_PROFILE
ARG AP_JAVA_VERSION
ARG SERVER_UPDATER_ENABLED
ARG SERVER_UPDATER_PROFILE
ARG SERVER_SOFTWARE
ARG SERVER_VERSION
ARG PLUGINS_UPDATER_ENABLED
ARG PLUGINS_UPDATER_PROFILE
ARG MODS_UPDATER_ENABLED
ARG MODS_UPDATER_PROFILE


###         < == BUILD == >
# From Eclipse Adoptium Temurin JRE
FROM eclipse-temurin:${JAVA_VERSION}-jre as build-0

# Set default updater arguments
ENV AP_JAVA_UPDATER_ENABLED ${AP_JAVA_UPDATER_ENABLED:-"true"}
ENV AP_JAVA_UPDATER_PROFILE ${AP_JAVA_UPDATER_PROFILE:-"AUTOMATIC"}
ENV AP_JAVA_VERSION         ${AP_JAVA_VERSION:-${JAVA_VERSION}} 
ENV SERVER_UPDATER_ENABLED  ${SERVER_UPDATER_ENABLED:-"true"}
ENV SERVER_UPDATER_PROFILE  ${SERVER_UPDATER_PROFILE:-"AUTOMATIC"}
ENV SERVER_SOFTWARE         ${SERVER_SOFTWARE:-"paper"}
ENV SERVER_VERSION          ${SERVER_VERSION:-"1.19.3"}
ENV PLUGINS_UPDATER_ENABLED ${PLUGINS_UPDATER_ENABLED:-"true"}
ENV PLUGINS_UPDATER_PROFILE ${PLUGINS_UPDATER_PROFILE:-"AUTOMATIC"}
ENV MODS_UPDATER_ENABLED    ${MODS_UPDATER_ENABLED:-"true"}
ENV MODS_UPDATER_PROFILE    ${MODS_UPDATER_PROFILE:-"AUTOMATIC"}

# Set default general arguments
ENV TARGET_SOFTWARE ${TARGET_SOFTWARE:-"MINECRAFT_SERVER"}
ENV START_ON_BOOT   ${START_ON_BOOT:-"true"}
ENV START_COMMAND   "java \
    -Xms${XMS} \
    -Xmx${XMX} \
    --add-modules=jdk.incubator.vector \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -jar ${SERVER_SOFTWARE}-latest.jar --nogui"
ENV AP_WEB_KEY      ${AP_WEB_KEY:-"NO_KEY"}

# Set alternate general arguments if PROXY_SERVER is 1 (Waterfall) or 2 (Velocity)
FROM build-0 as build-1
ENV SERVER_SOFTWARE ${SERVER_SOFTWARE:-"waterfall"}
ENV START_COMMAND   "java \
    -Xms${XMS} \
    -Xmx${XMX} \
    -XX:+UseG1GC \
    -XX:G1HeapRegionSize=4M \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+ParallelRefProcEnabled \
    -XX:+AlwaysPreTouch \
    -XX:MaxInlineLevel=15 \
    -jar ${SERVER_SOFTWARE}-latest.jar --nogui"

FROM build-1 as build-2
ENV SERVER_SOFTWARE ${SERVER_SOFTWARE:-"velocity"}

# Set final build
FROM build-${PROXY_SERVER:-0} as final
ENV SERVER_SOFTWARE ${SERVER_SOFTWARE:-"paper"}
ENV SERVER_VERSION  ${SERVER_VERSION:-"1.19.3"}

### Set AutoPlug Client download values
ENV AP_CLIENT_BUILD     "stable"
ENV AP_CLIENT_DOWNLOAD  "https://github.com/Osiris-Team/AutoPlug-Releases/raw/master/${AP_CLIENT_BUILD}-builds/AutoPlug-Client.jar"

### Set AutoPlug Plugin download values
ENV AP_PLUGIN_DOWNLOAD  "https://api.spiget.org/v2/resources/95568/versions/latest/download"

# Install needed packages before clearing the cache
RUN apt-get update && apt-get install -y --no-install-recommends curl\
    && rm -rf /var/lib/apt/lists/*

# Create base directories
WORKDIR /autoplug
RUN mkdir autoplug mods plugins

# Download latest AutoPlug-Client
RUN curl -# -o AutoPlug-Client.jar ${AP_CLIENT_DOWNLOAD}

# Download latest AutoPlug-Plugin
RUN (cd ./plugins && curl -# -o AutoPlug-Plugin.jar ${AP_PLUGIN_DOWNLOAD})

# Create container entrypoint
RUN touch entrypoint.sh
RUN print '#!/bin/bash\n\
\$JAVA_HOME/bin/java -jar /autoplug/AutoPlug-Client.jar\
' > entrypoint.sh

# Parse all arguments into "general.yml" and "updater.yml" configs
WORKDIR /autoplug/autoplug
RUN touch general.yml updater.yml
RUN printf '\
general: \n\
  autoplug: \n\
    target-software: ${TARGET_SOFTWARE}\n\
    start-on-boot: ${START_ON_BOOT}\n\
    system-tray: \n\
      enable: false \n\
  server: \n\
    start-command: ${START_COMMAND}\n\
    key: ${AP_WEB_KEY}\n\
' > general.yml

RUN printf '\
updater: \n\
  java-updater: \n\
    enable: ${AP_JAVA_UPDATER_ENABLED}\n\
    profile: ${AP_JAVA_UPDATER_PROFILE}\n\
    version: ${AP_JAVA_VERSION}\n\
  server-updater: \n\
    enable: ${SERVER_UPDATER_ENABLED}\n\
    profile: ${SERVER_UPDATER_PROFILE}\n\
    software: ${SERVER_SOFTWARE}\n\
    version: ${SERVER_VERSION}\n\
  plugins-updater: \n\
    enable: ${PLUGINS_UPDATER_ENABLED}\n\
    profile: ${PLUGINS_UPDATER_PROFILE}\n\
  mods-updater: \n\
    enable: ${MODS_UPDATER_ENABLED}\n\
    profile: ${MODS_UPDATER_PROFILE}\n\
' > updater.yml


###         < == RUNTIME == >
# From Eclipse Adoptium Temurin JRE
FROM eclipse-temurin:${JAVA_VERSION}-jre as runtime

# Copy everything from final build
COPY --from=final /autoplug /autoplug

# Set working directory
WORKDIR /autoplug

# Install needed packages before clearing the cache
RUN apt-get update && apt-get install -y --no-install-recommends tini\
    && rm -rf /var/lib/apt/lists/*

# RUN groupadd -r autoplug && useradd --no-log-init -r -g autoplug autoplug

# Expose default Minecraft port to host
EXPOSE 25565/tcp
EXPOSE 25565/udp

# Set image entrypoint
ENTRYPOINT ["/usr/bin/tini","--","/autoplug/entrypoint.sh"]