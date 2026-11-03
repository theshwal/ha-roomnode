#!/usr/bin/env bash
# Validation statique et compilation ESPHome — HA RoomNode (cible V1 4.3C)
#
# Ce script ne lit JAMAIS le fichier de secrets local du depot.
# Il genere dans un repertoire temporaire une variante de chaque profil ou les
# `!secret` sont remplaces par des valeurs factices, puis :
#   1. `esphome config`  -> validation du schema YAML + des contraintes ESPHome
#   2. `esphome compile` -> compilation complete du firmware (esp-idf)
#
# La compilation est optionnelle (ESPHOME_COMPILE=1) car elle telecharge la
# toolchain ESP-IDF (~1 Go) et peut prendre plusieurs minutes.
#
# Usage :
#   scripts/validate.sh              # config uniquement
#   ESPHOME_COMPILE=1 scripts/validate.sh
#
# Variables d'environnement :
#   ESPHOME_BIN      chemin de l'executable esphome (defaut: esphome)
#   ESPHOME_COMPILE  mettre a 1 pour lancer aussi la compilation
#
# Le repertoire de travail est cree par `mktemp -d` et supprime en sortie de
# trap. Aucun `rm -rf` n'est execute sur un chemin fourni par l'utilisateur :
# une variable d'environnement ne peut donc pas provoquer de suppression
# arbitraire.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESPHOME_BIN="${ESPHOME_BIN:-esphome}"

if ! command -v "$ESPHOME_BIN" >/dev/null 2>&1; then
  echo "ERREUR: '$ESPHOME_BIN' introuvable dans le PATH." >&2
  echo "       Installer ESPHome : pipx install esphome  (ou pip install esphome)" >&2
  exit 127
fi

# Repertoire de travail cree par mktemp : chemin aleatoire, cree par le
# script, jamais derive d'une saisie utilisateur.
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/roomnode-esphome-build.XXXXXXXX")"

cleanup() {
  if [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ]; then
    rm -rf -- "$WORKDIR"
  fi
}
trap cleanup EXIT INT TERM

echo "==> ESPHome: $("$ESPHOME_BIN" version)"
echo "==> Depot:   $REPO_ROOT"
echo "==> Build:   $WORKDIR"

mkdir -p "$WORKDIR"

# Valeurs factices. Aucune n'est un secret : elles servent uniquement a
# verifier que le schema est valide et que la compilation s'execute.
FAKE_WIFI_SSID="roomnode-validation"
FAKE_WIFI_PASSWORD="validation-not-a-secret"
FAKE_AP_PASSWORD="validation-not-a-secret"
FAKE_OTA_PASSWORD="validation-not-a-secret"
FAKE_API_KEY="Wm9zbk5vZGVWYWxpZGF0aW9uS2V5MDAwMDAwMDAwMDA="

# Profils testes : <nom de profil>:<fichier yaml de reference>
PROFILES=(
  "43c:roomnode-43c.yaml"
  "43c-ui:roomnode-43c-ui.yaml"
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
    echo "OK: compilation reussie (${name})"
  else
    echo "(compilation non demandee : ESPHOME_COMPILE=1 pour l'activer)"
  fi
done

echo
if [ "$status" -eq 0 ]; then
  echo "==> RESULTAT: toutes les validations demandees sont passees."
else
  echo "==> RESULTAT: au moins une validation a echoue." >&2
fi
exit "$status"
