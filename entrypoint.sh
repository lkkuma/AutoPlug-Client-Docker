#!/bin/bash

### Set global arguments with defaults
XMS=${XMS:="4G"}
XMX=${XMX:="4G"}
MOD_SERVER=${MOD_SERVER:="0"}
PROXY_SERVER=${PROXY_SERVER:="0"}
DEBUG=${DEBUG}

# Set AutoPlug Client download values
AP_WEB_KEY=${AP_WEB_KEY:="NO_KEY"}

# Set default updater arguments
SERVER_UPDATER_ENABLED=${SERVER_UPDATER_ENABLED:="true"}
SERVER_UPDATER_PROFILE=${SERVER_UPDATER_PROFILE:="AUTOMATIC"}
SERVER_SOFTWARE=${SERVER_SOFTWARE:="paper"}
SERVER_VERSION=${SERVER_VERSION:="latest"}
PLUGINS_UPDATER_ENABLED=${PLUGINS_UPDATER_ENABLED:="true"}
PLUGINS_UPDATER_PROFILE=${PLUGINS_UPDATER_PROFILE:="AUTOMATIC"}
MODS_UPDATER_ENABLED=${MODS_UPDATER_ENABLED:="true"}
MODS_UPDATER_PROFILE=${MODS_UPDATER_PROFILE:="AUTOMATIC"}

# Set default backup arguments
BACKUP_ENABLED=${BACKUP_ENABLED:="true"}
BACKUP_MAX_DAYS=${BACKUP_MAX_DAYS:="7"}
BACKUP_COOLDOWN=${BACKUP_COOLDOWN:="500"}
BACKUP_INCLUDE_ENABLED=${BACKUP_INCLUDE_ENABLED:="true"}
BACKUP_INCLUDE_LIST=${BACKUP_INCLUDE_LIST:="\
      - ./\n"}
BACKUP_EXCLUDE_ENABLED=${BACKUP_EXCLUDE_ENABLED:="true"}
BACKUP_EXCLUDE_LIST=${BACKUP_EXCLUDE_LIST:="\
      - ./autoplug/backups\n\
      - ./autoplug/downloads\n\
      - ./autoplug/system\n\
      - ./autoplug/logs\n\
      - ./plugins/dynmap\n\
      - ./plugins/WorldBorder\n"}

# Set default general arguments
TARGET_SOFTWARE=${TARGET_SOFTWARE:="MINECRAFT_SERVER"}
START_COMMAND=${START_COMMAND:="java \
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
-jar ${SERVER_SOFTWARE}-latest.jar --nogui"}

if ! [[ ${PROXY_SERVER} -eq 0 ]] ; then
    printf "PROXY_SERVER is set to [%s]" "${PROXY_SERVER}"
    SERVER_SOFTWARE=${SERVER_SOFTWARE:="waterfall"}
    START_COMMAND=${START_COMMAND:="java \
    -Xms${XMS} \
    -Xmx${XMX} \
    -XX:+UseG1GC \
    -XX:G1HeapRegionSize=4M \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+ParallelRefProcEnabled \
    -XX:+AlwaysPreTouch \
    -XX:MaxInlineLevel=15 \
    -jar ${SERVER_SOFTWARE}-latest.jar --nogui"}
fi

if [[ -f /app/autoplug/general.yml ]]; then
echo "general.yml already exists; skipping"
else
GENERAL_CONFIG=${GENERAL_CONFIG:="\
general: \n\
  autoplug: \n\
    target-software: ${TARGET_SOFTWARE}\n\
    start-on-boot: false\n\
    system-tray: \n\
      enable: false \n\
  server: \n\
    start-command: ${START_COMMAND}\n\
    key: ${AP_WEB_KEY}\n"}
printf "%b" "${GENERAL_CONFIG}" > /app/autoplug/general.yml
fi

if [[ -f /app/autoplug/updater.yml ]]; then
echo "updater.yml already exists; skipping"
else
UPDATER_CONFIG=${UPDATER_CONFIG="\
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
    profile: ${MODS_UPDATER_PROFILE}\n"}
printf "%b" "${UPDATER_CONFIG}" > /app/autoplug/updater.yml
fi

if [[ -f /app/autoplug/backup.yml ]]; then
echo "backup.yml already exists; skipping"
else
BACKUP_CONFIG=${BACKUP_CONFIG="\
backup: \n\
  enable: ${BACKUP_ENABLED}\n\
  max-days: ${BACKUP_MAX_DAYS}\n\
  cool-down: ${BACKUP_COOLDOWN}\n\
  include: \n\
    enable: ${BACKUP_INCLUDE_ENABLED}\n\
    list: ${BACKUP_INCLUDE_LIST}\n\
  exclude: \n\
    enable: ${BACKUP_EXCLUDE_ENABLED}\n\
    list: ${BACKUP_EXCLUDE_LIST}\n"}
printf "%b" "${BACKUP_CONFIG}" > /app/autoplug/backup.yml
fi

if [[ -f /app/autoplug/logger.yml ]]; then
echo "logger.yml already exists; skipping"
else
LOGGER_CONFIG=${LOGGER_CONFIG="\
logger: \n\
  debug: ${DEBUG}\n"}
fi

if [ -n "${DEBUG:+"true"}" ]; then \
    printf "%b" "${LOGGER_CONFIG}" > /app/autoplug/logger.yml; \
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

if [[ ${PROXY_SERVER} -eq 0 ]] && [[ ${MOD_SERVER} -eq 0 ]] ; then
    CMD="java -Dfile.encoding=UTF-8 -jar /app/AutoPlug-Client.jar .ip spigot 95568"
else
    CMD="java -Dfile.encoding=UTF-8 -jar /app/AutoPlug-Client.jar"
fi

exec ${CMD}