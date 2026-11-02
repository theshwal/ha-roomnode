#!/usr/bin/env bash
# Validation statique et compilation ESPHome — HA RoomNode
#
# Le dépôt ne contient AUCUN secret : ce script ne lit jamais `secrets.yaml`.
# Il génère dans un répertoire temporaire une variante de chaque profil où les
# `!secret` sont remplacés par des valeurs factices, puis :
#   1. `esphome config`  -> validation du schéma YAML + des contraintes ESPHome
#   2. `esphome compile` -> compilation complète du firmware (esp-idf)
#
# La compilation est optionnelle (ESPHOME_COMPILE=1) car elle télécharge la
# toolchain ESP-IDF (~1 Go) et peut prendre plusieurs minutes.
#
# Usage :
#   scripts/validate.sh              # config uniquement
#   ESPHOME_COMPILE=1 scripts/validate.sh
#
# Variables d'environnement :
#   ESPHOME_BIN   chemin de l'exécutable esphome (défaut: esphome)
#   ESPHOME_COMPILE  mettre à 1 pour lancer aussi la compilation
#   ESPHOME_WORKDIR  répertoire de travail (défaut: /tmp/roomnode-esphome-build)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESPHOME_BIN="${ESPHOME_BIN:-esphome}"
WORKDIR="${ESPHOME_WORKDIR:-/tmp/roomnode-esphome-build}"

if ! command -v "$ESPHOME_BIN" >/dev/null 2>&1; then
  echo "ERREUR: '$ESPHOME_BIN' introuvable dans le PATH." >&2
  echo "       Installer ESPHome : pipx install esphome  (ou pip install esphome)" >&2
  exit 127
fi

echo "==> ESPHome: $("$ESPHOME_BIN" version)"
echo "==> Dépôt:   $REPO_ROOT"
echo "==> Build:   $WORKDIR"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# Valeurs factices. Aucune n'est un secret : elles servent uniquement à
# vérifier que le schéma est valide et que la compilation s'exécute.
FAKE_WIFI_SSID="roomnode-validation"
FAKE_WIFI_PASSWORD="validation-not-a-secret"
FAKE_AP_PASSWORD="validation-not-a-secret"
FAKE_OTA_PASSWORD="validation-not-a-secret"
FAKE_API_KEY="Wm9zbk5vZGVWYWxpZGF0aW9uS2V5MDAwMDAwMDAwMDA="

# Profils testés : <nom de profil>:<fichier yaml de référence>
PROFILES=(
  "base:roomnode-base.yaml"
  "voice:roomnode-voice.yaml"
  "display:roomnode-display.yaml"
)

status=0

for profile in "${PROFILES[@]}"; do
  name="${profile%%:*}"
  src="${REPO_ROOT}/firmware/${profile#*:}"
  dst="${WORKDIR}/${name}.yaml"

  echo
  echo "=============================================================="
  echo "==> Profil: ${name}  (${src})"
  echo "=============================================================="

  # Copie du fichier et de ses includes (packages) dans le workdir, puis
  # substitution des !secret par des valeurs factices.
  cp "$src" "$dst"
  for inc in "$REPO_ROOT"/firmware/*.yaml; do
    base="$(basename "$inc")"
    [ "$base" = "$(basename "$src")" ] && continue
    cp "$inc" "${WORKDIR}/${base}"
  done

  python3 - "$WORKDIR" <<'PYEOF'
import pathlib
import re
import sys

workdir = pathlib.Path(sys.argv[1])
fake = {
    "wifi_ssid": "roomnode-validation",
    "wifi_password": "validation-not-a-secret",
    "wifi_ap_password": "validation-not-a-secret",
    "ota_password": "validation-not-a-secret",
    "api_encryption_key": "Wm9zbk5vZGVWYWxpZGF0aW9uS2V5MDAwMDAwMDAwMDA=",
}
pattern = re.compile(r"!secret\s+([A-Za-z0-9_]+)")

for path in sorted(workdir.glob("*.yaml")):
    text = path.read_text(encoding="utf-8")

    def repl(match: re.Match) -> str:
        key = match.group(1)
        if key not in fake:
            raise SystemExit(f"secret inconnu dans le YAML de test : {key}")
        return '"' + fake[key] + '"'

    new_text = pattern.sub(repl, text)
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        print(f"    [subst] {path.name}")
PYEOF

  echo "--- esphome config ${name}.yaml"
  if ! (cd "$WORKDIR" && "$ESPHOME_BIN" config "${name}.yaml"); then
    echo "ECHEC: validation de configuration (${name})" >&2
    status=1
    continue
  fi
  echo "OK: configuration valide (${name})"

  if [ "${ESPHOME_COMPILE:-0}" = "1" ]; then
    echo "--- esphome compile ${name}.yaml"
    if ! (cd "$WORKDIR" && "$ESPHOME_BIN" compile "${name}.yaml"); then
      echo "ECHEC: compilation (${name})" >&2
      status=1
      continue
    fi
    echo "OK: compilation réussie (${name})"
  else
    echo "(compilation non demandée : ESPHOME_COMPILE=1 pour l'activer)"
  fi
done

echo
if [ "$status" -eq 0 ]; then
  echo "==> RESULTAT: toutes les validations demandees sont passees."
else
  echo "==> RESULTAT: au moins une validation a echoue." >&2
fi
exit "$status"
