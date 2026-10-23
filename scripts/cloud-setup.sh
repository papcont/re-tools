#!/usr/bin/env bash
# Setup-Skript für die Claude-Code-Cloud-Umgebung.
# Inhalt in die Umgebungseinstellungen kopieren (Umgebungsmenü in der Titelleiste
# der Sitzung → Edit → Setup script). Neue Sitzungen führen es beim Start aus.
#
# Installiert REA (npm-Paket rea-agents, braucht Node 22.19+/24.11+/26+),
# trägt den MCP-Server "rea" in Claude Code ein und installiert den REA-Skill
# nach ~/.claude/skills/reverse-engineer-anything.
set -euo pipefail

npm install --global rea-agents
rea setup --all-detected --yes
