# Installation et flash — HA RoomNode, cible V1 4.3C

Carte cible : **Waveshare ESP32-S3-Touch-LCD-4.3C**
(ESP32-S3-WROOM-1-N16R8 : 16 Mo flash / 8 Mo PSRAM octal).
Framework : **ESP-IDF** via ESPHome.

> Aucun résultat physique n'est revendiqué par ce document. Les étapes « à
> valider avec la carte » sont explicitement signalées.

## 1. Prérequis

| Élément | Détail |
| --- | --- |
| ESPHome | 2026.10.x (version stable testée : **2026.10.1**) |
| Framework | `esp-idf`, version `recommended` (résolue en **ESP-IDF 5.5.6** par ESPHome 2026.10.1) |
| Python | 3.11+ (3.13 testé) |
| Câble | USB-C **données** |
| Carte | 16 Mo flash / 8 Mo PSRAM |

```bash
pipx install esphome     # ou : python3 -m venv .venv && .venv/bin/pip install esphome
esphome version
```

## 2. Secrets (jamais dans Git)

Le dépôt ignore le fichier de secrets local (voir `.gitignore`). Créer un
fichier local à partir du modèle :

```bash
cp secrets.example.yaml <votre-fichier-de-secrets-local.yaml>
$EDITOR <votre-fichier-de-secrets-local.yaml>
```

Clés attendues :

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

> **Note de sécurité.** ESPHome signale que le mot de passe OTA consomme du
> flash et de la RAM. Pour un déploiement durable, préférer
> `ota: - platform: esphome` avec `encryption:` (clé de chiffrement OTA) au
> mot de passe en clair. La configuration livrée conserve le mot de passe pour
> rester simple ; c'est un arbitrage à trancher avant mise en production.

## 3. Validation sans matériel

`scripts/validate.sh` ne lit **jamais** le fichier de secrets local. Il copie
les YAML dans un répertoire temporaire (`mktemp -d`), remplace chaque
`!secret` par une **valeur factice**, puis lance `esphome config` et,
en option, `esphome compile`.

```bash
# validation du schéma seul (rapide)
scripts/validate.sh

# validation + compilation complète (télécharge la toolchain ESP-IDF, ~1 Go)
ESPHOME_COMPILE=1 scripts/validate.sh
```

Variables d'environnement :

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `ESPHOME_BIN` | `esphome` | exécutable ESPHome |
| `ESPHOME_COMPILE` | `0` | mettre `1` pour compiler |

Le répertoire de travail est créé par `mktemp -d` et supprimé automatiquement
en sortie de script. Aucun chemin de build n'est accepté depuis
l'environnement : il n'existe donc aucune suppression arbitraire possible.

## 4. Profil livré

| Fichier | Contenu |
| --- | --- |
| `firmware/roomnode-43c-common.yaml` | socle : ESP32-S3 N16R8, esp-idf, Wi-Fi, API chiffrée, OTA, PSRAM octal |
| `firmware/roomnode-43c.yaml` | cible V1 : I²C unique, CH422G, écran RGB 800×480, tactile GT911, micro ES7210 + `voice_assistant` |

Brochage complet et sourcé : [gpio-43c.md](gpio-43c.md).

### 4.1 Flasher

```bash
esphome run firmware/roomnode-43c.yaml
```

Si le device n'est pas détecté, entrer en mode bootloader : maintenir **BOOT**
puis brancher le câble USB.

```bash
ls /dev/ttyACM* /dev/ttyUSB*
esphome run firmware/roomnode-43c.yaml --device /dev/ttyACM0
```

### 4.2 Console

```bash
esphome logs firmware/roomnode-43c.yaml
```

Messages utiles :

| Message | Signification |
| --- | --- |
| `Touch x=… y=…` | le tactile GT911 a signalé un contact |
| `Assist: client HA connecte` | HA a établi la session API |
| `Assist: ecoute en cours` | capture micro active |
| `Assist STT: <texte>` | transcription reçue de Home Assistant |
| `Assist erreur: <code> / <message>` | erreur remontée par le pipeline |

Le scan I²C (`scan: true`) doit montrer `0x5D` (GT911), `0x40` (ES7210),
`0x18` (ES8311) et l'adresse du CH422G. Le CH422G n'a pas d'adresse I²C unique
faisable dans ESPHome (il utilise des adresses dédiées par registre) : ne pas
conclure à une absence de réponse à son sujet.

## 5. Ce qui reste à valider avec la carte physique

Aucune de ces étapes n'a été exécutée : elles nécessitent le matériel.

1. **Boot et flash** du firmware compilé.
2. **PSRAM** : `psram: mode: octal` — la carte a-t-elle bien un PSRAM octal
   8 Mo ? Le modèle `esp32-s3-devkitc1-n16r8` suppose octal.
3. **Alimentation** : l'écran consomme ~550 mA. Le schéma prévoit une
   alimentation 5 V dédiée et un sélecteur de source (`PWR`). Le schéma
   signale que la sortie USB d'un PC peut être insuffisante (< 500 mA) :
   vérifier l'alimentation avant de conclure à un défaut d'affichage.
4. **Écran RGB** : affichage d'une image, couleurs et orientation correctes
   (mapping R/G/B issu du schéma, pas d'une autre carte Waveshare).
5. **Tactile GT911** : les 5 points, l'orientation des axes et la calibration.
6. **Rétroéclairage** : le modèle `mipi_rgb` le pilote via CH422G pin 2.
7. **ES7210** : réponse sur I²C `0x40` ; niveau de signal micro exploitable ;
   réglage de `mic_gain`.
8. **Canaux micro** : le pilote ESPHome `es7210` ne gère pas le TDM, il lit
   SDOUT1 (MIC1+MIC2). Vérifier que le canal 0 sélectionné n'est pas muet.
9. **Pipeline Assist** : une phrase transcrite et comprise.
10. **Stabilité** : pas de redémarrage sous charge (écran + audio + Wi-Fi).

## 6. Différences entre les niveaux de test

| Niveau | Commande | Ce qu'il prouve | Ce qu'il ne prouve pas |
| --- | --- | --- | --- |
| Syntaxe / schéma | `esphome config` | YAML valide, clés acceptées, IDs résolus, broches libres | que le matériel fonctionne |
| Compilation | `esphome compile` | le C++ compile et linke pour ESP32-S3 | que le flash démarre |
| Flash | `esphome run` | l'image est écrite sur la carte | que le comportement est correct |
| Essai physique | `esphome logs` + HA | le comportement réel observé | — |

Les niveaux 1 et 2 sont **couverts** par `scripts/validate.sh`. Les niveaux
3 et 4 **ne sont pas** couverts et restent à faire.

## 7. Compatibilité avec un changement d'écran

L'affichage est isolé dans `firmware/roomnode-43c.yaml` (blocs `display:`,
`touchscreen:`), mais le **modèle ESPHome `ESP32-S3-TOUCH-LCD-4.3` encapsule
tout le câblage RGB 16 bits** de cette carte. Pour changer d'écran :

- ne pas réutiliser ce modèle : déclarer un `model: custom` et renseigner
  `data_pins`, `de_pin`, `hsync_pin`, `vsync_pin`, `pclk_pin` et les porches
  à partir du **schéma de la nouvelle carte** ;
- vérifier la présence de PSRAM (le tampon 800×480 l'exige) ;
- pour un écran SPI, passer par `mipi_spi` (cf. le prototype 0,85″, branche
  `feature/issue-1-esphome-bringup`) ;
- un contrôleur tactile inconnu n'a **pas** de pilote généré magiquement :
  il faut `gt911` (GT911), `ft63xx`, ou un composant externe.
