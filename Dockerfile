# Set global arguments with defaults
ARG JAVA_VERSION="20"
ARG PROXY_SERVER="0"

###         < == BUILD == >
# From Eclipse Adoptium Temurin JRE
FROM eclipse-temurin:${JAVA_VERSION}-jdk as build-0

# Set global arguments
ARG XMS
ARG XMX
ARG PROXY_SERVER
ARG DEBUG

ARG TARGET_SOFTWARE
ARG START_COMMAND
ARG AP_WEB_KEY

ARG SERVER_UPDATER_ENABLED
ARG SERVER_UPDATER_PROFILE
ARG SERVER_SOFTWARE
ARG SERVER_VERSION
ARG PLUGINS_UPDATER_ENABLED
ARG PLUGINS_UPDATER_PROFILE
ARG MODS_UPDATER_ENABLED
ARG MODS_UPDATER_PROFILE

# Set default global arguments
ENV XMS             ${XMS:-"4G"}
ENV XMX             ${XMX:-"4G"}
ENV PROXY_SERVER    ${PROXY_SERVER:-"0"}
ENV DEBUG           ${DEBUG:+"1"}

# Set default updater arguments
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

### Set alternate start command if PROXY_SERVER is 1 (Bungeecord/Waterfall/Travertine/Velocity)
FROM build-0 as build-1
RUN printf "PROXY_SERVER is set to [%s]" "${PROXY_SERVER}"
ENV SERVER_VERSION  "latest"
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

### Set final build
FROM build-${PROXY_SERVER} as build-final

# Install needed packages
RUN apt-get update && apt-get install -y --no-install-recommends curl=\*

# Create base directories
WORKDIR /autoplug
RUN mkdir autoplug mods plugins

# Set AutoPlug Client download values
ENV AP_CLIENT_BUILD     "stable"
ENV AP_CLIENT_DOWNLOAD  "https://github.com/Osiris-Team/AutoPlug-Releases/raw/master/${AP_CLIENT_BUILD}-builds/AutoPlug-Client.jar"

# Download latest AutoPlug-Client
RUN curl -o AutoPlug-Client.jar -L ${AP_CLIENT_DOWNLOAD}

# Stage AutoPlug-Plugin.jar to download via AutoPlug-Client
WORKDIR /autoplug/plugins
ENV AP_PLUGIN_YML "\
name: AutoPlug-Plugin\n\
version: 0\n\
authors: [OsirisTeam]"
RUN printf "%b" "${AP_PLUGIN_YML}" > plugin.yml
RUN jar cMf AutoPlug-Plugin.jar plugin.yml && rm plugin.yml

# Parse all arguments into their respective configs configs
WORKDIR /autoplug/autoplug

ENV GENERAL_CONFIG "\
general: \n\
  autoplug: \n\
    target-software: ${TARGET_SOFTWARE}\n\
    start-on-boot: false\n\
    system-tray: \n\
      enable: false \n\
  server: \n\
    start-command: ${START_COMMAND}\n\
    key: ${AP_WEB_KEY}\n"
RUN printf "%b" "${GENERAL_CONFIG}" > general.yml

ENV UPDATER_CONFIG "\
updater: \n\
  java-updater: \n\
    enable: false\n\
    profile: AUTOMATIC\n\
    version: 0\n\
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
    profile: ${MODS_UPDATER_PROFILE}\n"
RUN printf "%b" "${UPDATER_CONFIG}" > updater.yml

ENV BACKUP_CONFIG "\
backup: \n\
  enable: true\n\
  max-days: 7\n\
  cool-down: 500\n\
  include: \n\
    enable: true\n\
    list: \n\
      - ./\n\
  exclude: \n\
    enable: true\n\
    list: \n\
      - ./autoplug/backups\n\
      - ./autoplug/downloads\n\
      - ./autoplug/system\n\
      - ./autoplug/logs\n\
      - ./plugins/dynmap\n\
      - ./plugins/WorldBorder\n"
RUN printf "%b" "${BACKUP_CONFIG}" > backup.yml

# Run debug operations if DEBUG is not null
ENV LOGGER_CONFIG "\
logger: \n\
  debug: true\n"

RUN if [ -n "${DEBUG}" ]; then \
printf "%b" "${LOGGER_CONFIG}" > logger.yml; \
printf "DEBUG IS ENABLED: [%s]\n\
 \n\
-- General Config:\n\
%b\n\
 \n\
-- Updater Config:\n\
%b\n\
 \n\
-- Logger Config:\n\
%b\n\
 \n" \
"${DEBUG}" \
"${GENERAL_CONFIG}" \
"${UPDATER_CONFIG}" \
"${LOGGER_CONFIG}"; \
fi 

###         < == RUNTIME == >
# From Eclipse Adoptium Temurin JRE
FROM eclipse-temurin:${JAVA_VERSION}-jre as runtime

# Copy everything from final build
COPY --from=build-final /autoplug /autoplug

# Set and mount working directory
WORKDIR /autoplug
VOLUME /autoplug

# Install needed packages before clearing the cache
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini=\*\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create and set autoplug user and group
RUN groupadd -r -g 10000 autoplug \
    && useradd --no-log-init -r -u 10001 -g autoplug autoplug
RUN chown -R autoplug:autoplug /autoplug

USER autoplug:autoplug

# Expose default Minecraft port to host
EXPOSE 25565/tcp
EXPOSE 25565/udp

# Set image entrypoint
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["java","-jar","/autoplug/AutoPlug-Client.jar"]