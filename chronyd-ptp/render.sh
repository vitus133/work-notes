#!/bin/bash
restart_chronyd=$(cat src/restart-chronyd | base64 -w0)
ptp_sync_check=$(cat src/ptp-sync-check | base64 -w0)
conditional_start=$(cat src/20-conditional-start.conf)
restart_service=$(cat src/chronyd-restart.service)
restart_timer=$(cat src/chronyd-restart.timer)
jinja -E restart_chronyd -E ptp_sync_check -E conditional_start -E restart_service -E restart_timer templates/mc-chronyd-dynamic.json.j2 |yq -y