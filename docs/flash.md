# Installation et flash — HA RoomNode

Carte cible : **Waveshare ESP32-S3-LCD-0.85** (ESP32-S3-PICO-1-N8R8, 8 Mo flash,
8 Mo PSRAM). Framework : **ESP-IDF** via ESPHome.

> Aucun résultat physique n'est revendiqué par ce document. Les étapes « à valider
> avec la carte » sont explicitement signalées.

## 1. Prérequis

| Élément | Détail |
| --- | --- |
| ESPHome | 2026.10.x (version stable testée : **2026.10.1**) |
| Framework | `esp-idf`, version `recommended` (résolu en **5.5.6** par ESPHome 2026.10.1) |
| Python | 3.11+ (3.13 testé) |
| Câble | USB-C **données** (la carte expose un USB natif ESP32-S3) |
| Carte | 8 Mo flash / 8 Mo PSRAM |

Installation d'ESPHome :

```bash
pipx install esphome     # ou : python3 -m venv .venv && .venv/bin/pip install esphome
esphome version
```

## 2. Secrets (jamais dans Git)

Le dépôt ignore `secrets.yaml` (voir `.gitignore`). Créer un fichier local :

```bash
cp secrets.example.yaml secrets.yaml
$EDITOR secrets.yaml
```

Les secrets attendus :

| Clé | Rôle |
| --- | --- |
| `wifi_ssid` / `wifi_password` | réseau local de la pièce |
| `wifi_ap_password` | point d'accès de secours (≥ 8 caractères) |
| `ota_password` | mot de passe des mises à jour OTA |
| `api_encryption_key` | clé de chiffrement de l'API ESPHome (base64, 32 octets) |

Générer la clé API :

```bash
esphome encrypt "une-phrase-de-32-octets-minimum-ici"
```

> **Note de sécurité.** ESPHome signale que le mot de passe OTA consomme du flash
> et de la RAM. Pour un déploiement durable, préférer `ota: - platform: esphome`
> avec `encryption:` (clé de chiffrement OTA) au mot de passe en clair.
> La configuration livrée ici conserve le mot de passe pour rester simple et
> compatible avec les versions plus anciennes ; c'est un choix à arbitrer
> avant mise en production.

## 3. Validation sans matériel

Le script de validation **ne lit jamais `secrets.yaml`**. Il copie les YAML dans
un répertoire temporaire, remplace chaque `!secret` par une **valeur factice**,
puis lance `esphome config` et, en option, `esphome compile`.

```bash
# validation du schéma seul (rapide)
scripts/validate.sh

# validation + compilation complète (télécharge la toolchain ESP-IDF, ~1 Go)
ESPHOME_COMPILE=1 scripts/validate.sh
```

Variables d'environnement utiles :

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `ESPHOME_BIN` | `esphome` | exécutable ESPHome |
| `ESPHOME_COMPILE` | `0` | mettre `1` pour compiler |

Le répertoire de travail est créé par `mktemp -d` (chemin aléatoire) et
supprimé automatiquement en sortie de script. Aucun chemin de build n'est
accepté depuis l'environnement : il n'existe donc aucune suppression
arbitraire possible.

## 4. Profils de firmware

| Fichier | Contenu | Usage |
| --- | --- | --- |
| `firmware/roomnode-common.yaml` | plateforme, Wi-Fi, API, OTA, PSRAM, boutons | socle partagé (package) |
| `firmware/roomnode-base.yaml` | socle seul | bring-up : vérifier Wi-Fi + API + console |
| `firmware/roomnode-voice.yaml` | socle + ES7210 + micro I2S + `voice_assistant` | capture micro → Assist |

### 4.1 Bring-up minimal

```bash
esphome run firmware/roomnode-base.yaml
```

Attendus une fois la carte branchée : le device apparaît dans Home Assistant,
la console affiche la connexion Wi-Fi.

### 4.2 Micro + Assist

```bash
esphome run firmware/roomnode-voice.yaml
```

**Sans haut-parleur.** L'ES8311 (DAC), le NS4150 et `PA_CTRL` (GPIO7) ne sont
pas activés : la voix sortante reste assure par l'Echo de la pièce
(voir `docs/architecture.md`).

## 5. Flash initial en USB (si le device ne démarre pas)

```bash
# entrer en mode bootloader : maintenir BOOT puis appuyer RESET
esphome run firmware/roomnode-base.yaml --device /dev/ttyACM0
```

Si `/dev/ttyACM0` n'apparaît pas :

```bash
ls /dev/ttyACM* /dev/ttyUSB*
dmesg | tail -20
```

## 6. Console

```bash
esphome logs firmware/roomnode-voice.yaml
```

Messages utiles du profil voix :

| Message | Signification |
| --- | --- |
| `Assist: client HA connecte` | HA a établi la session API |
| `Assist: ecoute en cours` | capture micro active |
| `Assist STT: <texte>` | transcription reçue de Home Assistant |
| `Assist erreur: <code> / <message>` | erreur remontée par le pipeline |

Le micro ES7210 est diagnostiqué au démarrage par ESPHome
(`ES7210 audio ADC` dans `dump_config`) ; un échec d'initialisation du codec
apparaît dans les logs.

## 7. Ce qui reste à valider avec la carte physique

Aucune de ces étapes n'a été exécutée : elles nécessitent le matériel.

1. **Boot et flash** : le firmware compile se flashe-t-il et démarre-t-il ?
2. **PSRAM** : `psram: mode: octal` — la carte a-t-elle bien un PSRAM octal
   8 Mo (vs quad) ? Le modèle `esp32-s3-devkitc1-n8r8` suppose octal.
3. **Wi-Fi / API** : connexion au réseau et apparition dans HA.
4. **ES7210** : le codec répond-il sur I²C (adresse `0x40`) ? Un `i2c: scan: true`
   est activé : la console doit montrer `0x40` (et `0x18` pour l'ES8311).
5. **Capture micro** : le niveau du signal est-il exploitable ? Ajuster
   `mic_gain` (0…37,5 dB) si saturation ou silence.
6. **Canaux** : le pilote ESPHome `es7210` lit SDOUT1 (MIC1+MIC2 en TDM).
   Vérifier que le canal 0 sélectionné n'est pas muet ; tester le canal 1 en
   secours.
7. **Pipeline Assist** : une phraseComplete et reproducible (niveau de la
   parole, bruit ambiant, distance au micro).
8. **Boutons** : BOOT et PLUS réagissent ; ne pas tester PWR de façon répétée
   (il commande l'alimentation).
9. **Stabilité** : pas de redémarrage sous charge audio + Wi-Fi.

## 8. Différences entre les niveaux de test

| Niveau | Commande | Ce qu'il prouve | Ce qu'il ne prouve pas |
| --- | --- | --- | --- |
| Syntaxe / schéma | `esphome config` | YAML valide, clés acceptées, IDs résolus, broches libres | que le matériel fonctionne |
| Compilation | `esphome compile` | le code C++ compile et linke pour ESP32-S3 | que le flash démarre |
| Flash | `esphome run` | l'image est écrite sur la carte | que le comportement est correct |
| Essai physique | `esphome logs` + HA | le comportement réel observé | — |

Les niveaux 1 et 2 sont **couverts** par `scripts/validate.sh`. Les niveaux
3 et 4 **ne sont pas** couverts et restent à faire.

## 9. Compatibilité avec un écran plus grand

Le firmware 0,85″ est conservé comme **prototype**. L'affichage est isolé
dans son propre bloc (`display:` / `mipi_spi`), et le tableau GPIO de
`docs/gpio.md` est propre à cette carte. Pour migrer vers un écran plus
grand :

- ne pas modifier `roomnode-common.yaml` ni `roomnode-voice.yaml` ;
- créer un nouveau profil (par exemple `roomnode-display-lg.yaml`) qui
  redéfinit uniquement le bloc `display:` et son bus `spi:` ;
- vérifier la taille du tampon et la présence de PSRAM (le `mipi_spi` avec
  LVGL consomme de la RAMPSRAM) ;
- le GC9107 n'a de pilote ESPHome natif que via le modèle `GC9107` de
  `mipi_spi` (dérivé ST7789V). Un contrôleur inconnu n'a **pas** de pilote
  généré magiquement : il faut une séquence d'initialisation validée ou un
  composant externe.
