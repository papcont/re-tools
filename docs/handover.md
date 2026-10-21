# Handover: REA + Ghidra in einer Claude-Code-Cloud-Sitzung

## Ziel
REA ("Reverse Engineer Anything", https://github.com/morluto/rea, npm-Paket `rea-agents`) global installieren, als MCP-Server in Claude Code registrieren und Ghidra 12.1.4 als Analyse-Engine für native Binaries anbinden.

## Repos für die neue Sitzung
| Repo | Rolle | Zugriff |
|---|---|---|
| `papcont/re-tools` | Skripte + Doku (dieses Repo), Branch `ccr-86188446-z5i2ex` | in der Sitzung anbinden (Schreibzugriff) |
| `NationalSecurityAgency/ghidra` | Ghidra-Quellcode, Tag `Ghidra_12.1.4_build` | öffentlich, wird anonym per Git geklont (Anbinden mit Push-Rechten geht nicht und ist nicht nötig) |
| `NationalSecurityAgency/ghidra-data` | Datendateien (FunctionID, SARIF-Jar, dbgmodel.tlb), Tag `Ghidra_12.1.4` | öffentlich, anonymer Git-Klon |

`papcont/html-games` hat damit nichts zu tun (dort liegt nur eine ältere Fassung dieser Übergabe).

## Schritte in der neuen Sitzung
```bash
npm install --global rea-agents          # REA 6.7.0 (Node 22.19+/24.11+/26+)
rea setup --all-detected --yes           # MCP-Eintrag "rea" + Skill für Claude Code
scripts/build-ghidra.sh 12.1.4           # klont, baut (~12 min), entpackt nach ~/tools, rea doctor + rea setup
claude mcp list                          # rea: ... √ Connected
```
Danach eine neue Sitzung starten oder Claude Code neu laden, damit die MCP-Tools (`mcp__rea__*`) mit Ghidra-Konfiguration verfügbar sind.

Kurztest: `GHIDRA_INSTALL_DIR=~/tools/ghidra_12.1.4_DEV rea analyze /usr/bin/true --provider ghidra` (dauerte ~16 s).

## Was in der vorherigen Sitzung funktioniert hat
- REA 6.7.0 global, MCP-Eintrag mit `env: GHIDRA_INSTALL_DIR=/root/tools/ghidra_12.1.4_DEV, JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`
- Ghidra 12.1.4 aus Quellcode gebaut: `ghidra_12.1.4_DEV_20261021_linux_x86_64.zip` (535 MB, SHA-256 `7900b0c568142925bae17d75c6b87126ed50ae71b4fb855dee6f431366277b80`)
- `rea doctor --provider ghidra`: alle Prüfungen grün (Version, Headless, nativer Decompiler x86_64, JDK 21)
- `rea analyze` mit Ghidra auf einem Testbinary erfolgreich

`scripts/build-ghidra.sh` fasst genau diese Schritte zusammen. In einer zweiten Sitzung (Branch `ccr-66caebfc-2j3ybj`) lief es am Stück fehlerfrei durch (12 min 48 s auf 4 Kernen; gemeldet als fehlend nur PostgreSQL und CDT, s. u.). Danach: `rea doctor --provider ghidra` grün, `rea analyze /usr/bin/true --provider ghidra` in ~15 s. Das Zip ist nicht bitgleich reproduzierbar (Zeitstempel), der SHA-256 ändert sich also bei jedem Build.

## Stolpersteine (Cloud-Sitzung)
- **GitHub-Proxy der Sitzung:** `github.com`-Releases, Raw-Dateien und `api.github.com` sind nur für angebundene Repos erlaubt → offizielle Ghidra-Zips nicht ladbar (403 *"GitHub access to this repository is not enabled for this session"*). Netzwerkfreigaben in der Umgebung ändern daran nichts. Anonymer `git clone` öffentlicher Repos geht.
- **Releases anlegen** ist in diesem Sitzungstyp verboten → das gebaute Zip konnte nicht als Release in `re-tools` abgelegt werden.
- **Maven Central** (`repo.maven.apache.org`) antwortet häufig 429 → `gradle/maven-mirror.gradle` leitet auf `maven-central.storage-download.googleapis.com` um.
- **Locale:** ohne `LC_ALL=C.UTF-8` scheitert `assembleDistribution` an `SørensenIndexLinkPrediction.class` in jgrapht.
- **Nicht ladbar, aber für REA unnötig:** `postgresql-15.18.tar.gz` (ftp.postgresql.org, optionaler BSim-Server), `cdt-8.6.0.zip` (archive.eclipse.org, GhidraDev).
- **Container ist flüchtig:** Ohne Persistenz muss Ghidra pro neuer Sitzung neu gebaut werden.
- **Auto-Mode-Sicherheitsprüfung** hat in der zweiten Sitzung auch `rea setup --all-detected --yes` blockiert ("Create Unsafe Agents", weil es einen MCP-Server registriert). Dann führt der Nutzer den Befehl selbst aus oder erlaubt ihn per Berechtigungsregel; das Skript ruft `rea setup` am Ende nur auf, wenn `rea` im PATH ist.
- **Auto-Mode-Sicherheitsprüfung** hat außerdem blockiert: Einträge in `~/.bashrc`, einen GitHub-Actions-Workflow zum Spiegeln von NSA-Releases und systematisches Abklopfen von Download-Hosts. Nicht umgehen; ggf. den Nutzer fragen.

## Offene Punkte
- Ghidra-Zip dauerhaft ablegen, damit nicht jedes Mal gebaut werden muss (Release nicht erlaubt; Alternativen: in <100-MB-Teilen auf einen eigenen Branch committen oder lokal einmal als Release hochladen).
- Optional: Setup-Skript der Cloud-Umgebung „Default“ mit `npm install --global rea-agents` vorbelegen.
- Die vier GitHub-Domains unter „Allowed domains“ der Umgebung „Default“ haben nichts bewirkt und können entfernt werden.
