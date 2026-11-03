# Capteurs externes — SHT40 + radar LD2410C (issue #3)

Cible : Waveshare **ESP32-S3-Touch-LCD-4.3C** (profil `roomnode-43c-full`).

> Aucun essai physique. Ce document décrit un **câblage prévu et vérifié sur
> les sources officielles**, pas un montage validé.

## Sources

| # | Source | Ce qui en est tiré |
| --- | --- | --- |
| 1 | Schéma officiel 4.3C rev. V1.1 (`github.com/waveshareteam/ESP32-S3-Touch-LCD-4.3C` → `hardware/schematics/`) | GPIO disponibles, rails 3,3 V / 5 V, nets `I2S_DSDIN`, `SD_SCK` |
| 2 | Fiche ESPHome `sht4x` | adresse I²C par défaut `0x44` |
| 3 | Fiche ESPHome `ld2410` | UART 256000 bauds, 8N1, **TX et RX obligatoires**,_TX via `uart_id` |
| 4 | Fiche HLK-LD2410C (constructeur Hi-Link) | alimentation **5 V** (5–12 V), logique UART **3,3 V**, ~79 mA moyen, pointe > 200 mA |

## SHT40 — température et humidité

Le SHT40 parle I²C et **n'utilise aucun GPIO supplémentaire** : il se
branche sur le bus I²C de la carte (GPIO8 SDA / GPIO9 SCL), à l'adresse
`0x44`.

C'est un point important : le bus I²C de la 4.3C est **unique** et partagé
entre GT911 (`0x5D`), CH422G, ES7210 (`0x40`), ES8311 (`0x18`), RTC PCF85063
et désormais SHT40 (`0x44`). Il faut vérifier que la charge du bus tient avec
six périphériques.

| SHT40 | Connecteur 4.3C |
| --- | --- |
| VCC | 3,3 V (`Vout_3V3` / `I2C_VCC`) |
| GND | GND |
| SDA | GPIO8 (`CTP_SDA` / `D_SDA`) |
| SCL | GPIO9 (`CTP_SCL` / `D_SCL`) |

Le SHT40 doit être **éloigné de l'ESP32, de l'écran et de l'alimentation** :
la carte chauffant, la mesure serait biaisée. Prévoir une faible liaison
(≈ 10–20 cm) et un flux d'air.

## LD2410C — présence

Le LD2410C (24 GHz FMCW) détecte présence **y compris immobile**, ce qui est
le besoin V1 (présence stationnaire).

### Câblage

| LD2410C | Broche 4.3C | Note |
| --- | --- | --- |
| TX | GPIO15 (RX ESP32) | `I2S_DSDIN` — TX vers l'ES8311, **non utilisé** en V1 |
| RX | GPIO12 (TX ESP32) | `SD_SCK` — horloge carte TF, **non utilisée** en V1 |
| OUT | — | non câblé : la présence est lue par l'UART |
| GND | GND | |
| VCC | **5 V** | voir ci-dessous |

Les deux GPIO retenus (`GPIO15`, `GPIO12`) sont **libres** sur la 4.3C : le
profil V1 n'active ni le DAC ES8311 ni la carte TF. Aucun conflit avec
l'écran RGB, le GT911, le CH422G, le bus I²C, l'I²S micro, l'USB ni le
console UART.

### Alimentation — point critique

> ⚠️ **Le LD2410C exige 5 V (5 à 12 V). Il ne doit JAMAIS être alimenté par
> le rail 3,3 V de la carte.** Un sous-alimentation en 3,3 V fait redémarrer
> le module en boucle et pollue la mesure.

La 4.3C dispose d'un rail 5 V (`DC_5V` / `VOUT_5V`) produit par le
convertisseur SY8293FCC, avec un sélecteur de source `PWR` (USB ou
batterie). Deux points à vérifier avant de brancher :

1. **Charge totale.** L'écran consomme à lui seul ~550 mA et le rail 5 V est
   dimensionné pour l'ensemble. Le radar ajoute ~80 mA moyens, avec des
   pointes. Le schéma signale par ailleurs que la sortie USB d'un PC peut être
   insuffisante (< 500 mA) pour l'écran seul : **prévoir une alimentation 5 V
   dédiée** plutôt que de dépendre de l'USB du PC.
2. **Bruit.** Le radar et son convertisseur partageant le rail 5 V avec
   l'écran, des perturbations audio sont possibles. C'est exactement le
   risque identifié par l'issue #3 (« sans perturber la voix ») : à mesurer
   une fois le montage fait.

### Niveaux logiques

Les signaux UART sont en **3,3 V des deux côtés** (TX du radar en 3,3 V, RX
attendu en 3,3 V) : **aucun convertisseur de niveau** n'est nécessaire entre
l'ESP32-S3 et le LD2410C. Attention : la tension d'**alimentation** est 5 V
alors que la tension de **signal** est 3,3 V — ne pas confondre les deux.

## Configuration ESPHome

`firmware/roomnode-43c-sensors.yaml` (package) et
`firmware/roomnode-43c-full.yaml` (profil complet).

Points de la fiche ESPHome `ld2410` respectés :

- `baud_rate: 256000`, `data_bits: 8`, `parity: NONE`, `stop_bits: 1` ;
- `tx_pin` **et** `rx_pin` obligatoires (validation finale du composant) ;
- `rx_buffer_size: 512` (la valeur par défaut de 256 est faible pour un flux
  à 256000 bauds).

Entités exposées : présence, cible mobile, cible immobile, distances (mobile,
immobile, détection), énergies (mobile, immobile), température et humidité.

## Calibration du radar

La fiche ESPHome décrit la procédure : activer le **mode ingénierie**, suivre
les énergies `g0`…`g8` (mouvement / immobile), ajuster les seuils, puis
désactiver le mode. Les seuils par défaut sont ceux de l manufacturer's
(déjà dans ESPHome) ; ils ne sont pas adaptés à une pièce donnée.

**Le mode ingénierie n'est pas activé dans le firmware livré** : il consomme
davantage de ressources et l'issue #3 demande de ne pas perturber la voix.

## Preuves de compilation

Commande :

```bash
ESPHOME_COMPILE=1 scripts/validate.sh
```

Résultat : **exit code 0**.

| Profil | Taille image | RAM (DIRAM) | Flash (part. app) |
| --- | ---: | ---: | ---: |
| `43c` (V1 seul) | 919 307 o | 110 235 o (32,3 %) | 11,3 % |
| `43c-full` (+ capteurs) | 937 623 o | 111 583 o (32,6 %) | 11,5 % |

Les capteurs ajoutent **18 316 o de flash** et **1 348 o de RAM** : l'impact
est négligeable.

Extrait de journal : [`docs/build-43c-sensors-output.txt`](build-43c-sensors-output.txt).

## Limites — **aucun test physique n'a été réalisé**

1. Le SHT40 répond-il à `0x44` sur le bus I²C à six périphériques ?
2. Le LD2410C répond-il en UART à 256000 bauds sur GPIO12/15 ?
3. Le rail 5 V tient-il la charge écran + radar ? Quelle source utiliser ?
4. Le radar perturbe-t-il la capture micro (bruit du convertisseur) ?
5. Le SHT40 mesure-t-il la température de l'air et non celle de la carte ?
6. La présence immobile est-elle détectée de façon fiable, sans faux
   positifs ?
7. Le radar redémarre-t-il sur pic de courant ?

## Limites connues

- **Un seul UART.** La 4.3C consomme UART0 (I²S) et UART1 (I²C). L'UART du
  radar passe par un port libre routé par la matrice GPIO d'ESPHome : c'est un
  UART matériel avec routage logiciel, pas un UART logiciel émulé. À 256000
  bauds cela reste confortable, mais le débit effectif est à mesurer.
- **GPIO12/15 ne seront plus libres** pour une carte TF ou un DAC : cette
  PR les affecte au radar.
- Le CH422G pourrait piloter d'autres peripheral (PA_CTRL, CS TF) : non
  utilisé ici.
