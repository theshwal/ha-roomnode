# BOM et contraintes de boîtier — cible V1 4,3″

Carte cible : **Waveshare ESP32-S3-Touch-LCD-4.3C**
(SKU **33799** sans boîtier / **33630** avec boîtier plastique).

> Aucun essai physique. Cette BOM est établie **à partir des sources
> officielles** (fiche Waveshare, schéma rev. V1.1, notices des
> capteurs). Aucune référence n'a été achetée, montée ni photographiée.

## 1. Nomenclature

### 1.1 Carte hôte

| Élément | Spécification | Source |
| --- | --- | --- |
| Carte | Waveshare ESP32-S3-Touch-LCD-4.3C, SKU 33799 (sans boîtier) ou 33630 (avec boîtier) | fiche Waveshare |
| Module | ESP32-S3-WROOM-1-**N16R8** (16 Mo flash / 8 Mo PSRAM octal) | schéma, fiche |
| Écran | 4,3″ capacitif **800×480**, 65 K couleurs, interface RGB 16 bits | fiche Waveshare |
| Contrôleur tactile | **GT911**, 5 points, I²C `0x5D` | schéma, composant ESPHome `gt911` |
| Codec audio | **ES8311** (DAC) + **ES7210** (ADC micro 4 canaux) | schéma, fiche |
| Ampli | **NS4150B** | schéma |
| Expander I/O | **CH422G** (reset écran, rétroéclairage, reset tactile, PA_CTRL, CS TF) | schéma, composant ESPHome `ch422g` |
| Horloge | **PCF85063ATL** + quartz 32,768 kHz | schéma |
| Carte TF | slot microSD / SDIO | fiche |
| E/S isolées | 2 entrées (DI0/DI1), 2 sorties (DO0/DO1), opto-couplées (PC817, PC814) | schéma |
| Alimentation | USB-C, charge Li-ion **CS8501**, élévateur **SY8293FCC** (5 V), TMI3112H (`DC_5V`) | schéma |
| Boutons | BOOT, RST | fiche |

### 1.2 Capteurs externes (issue #3)

| Élément | Spécification | Source | Note |
| --- | --- | --- | --- |
| Température + humidité | **SHT40**, breakout I²C, adresse `0x44`, 3,3 V | fiche ESPHome `sht4x` | I²C **partagé** avec la carte |
| Radar de présence | **HLK-LD2410C**, 24 GHz FMCW, 5–12 V, UART 256000 8N1 | fiche constructeur Hi-Link | détecte la présence **immobile** |

### 1.3 Câblage et connectique

| Élément | Détail |
| --- | --- |
| Câble USB-C | **données** (programmation + logs). Le schéma signale que la sortie USB d'un PC peut être insuffisante pour l'écran (< 500 mA) |
| Câbles capteurs | dupont ou connecteurs 2,54 mm ; longueur courte pour l'I²C (bus partagé à 6 périphériques) |
| Dissipation | le radar et l'écran partagent le rail 5 V : prévoir une **alimentation 5 V dédiée** si le budget est serré |

## 2. Câblage — récapitulatif

Le détail complet, avec sources, est dans [gpio-43c.md](gpio-43c.md). Version
résumée :

| Fonction | GPIO / pin |
| --- | --- |
| I²C unique (GT911 `0x5D`, ES7210 `0x40`, ES8311 `0x18`, SHT40 `0x44`, PCF85063, CH422G) | SDA **GPIO8**, SCL **GPIO9** |
| Touchile GT911 | IRQ **GPIO4**, reset **CH422G pin 1** |
| Écran RGB | PCLK **GPIO7**, HSYNC **GPIO46**, VSYNC **GPIO3**, DE **GPIO5**, data R/G/B sur 19 GPIO (voir doc) |
| Reset écran / rétroéclairage | **CH422G pin 3** / **pin 2** |
| Micro ES7210 | MCLK **GPIO6**, SCLK **GPIO44**, LRCK **GPIO16**, ASDOUT **GPIO43** |
| DAC ES8311 (inutilisé) | DSDIN **GPIO15** |
| Enable ampli NS4150 (inutilisé) | **CH422G pin 4** |
| Radar LD2410C (issue #3) | TX **GPIO15**, RX **GPIO12** |
| Carte TF (inutilisée) | MOSI **GPIO11**, SCK **GPIO12**, MISO **GPIO13**, CS **CH422G pin 4** |

## 3. Alimentation — contraintes à respecter

| Point | Contrainte | Source |
| --- | --- | --- |
| Écran 800×480 | ~550 mA | note du schéma : « The screen itself consumes close to 550mA » |
| USB d'un PC | peut être **insuffisant** (< 500 mA) | note du schéma |
| Rail 5 V | `DC_5V` (TMI3112H) et `VOUT_5V` (SY8293FCC, 2,8 A) | schéma |
| Sélecteur de source | `PWR` : USB ou batterie | schéma |
| LD2410C | **5 V** (5–12 V), logique 3,3 V, ~79 mA moyen, pointe > 200 mA | notice Hi-Link |
| ⚠️ Ne jamais | alimenter le LD2410C par le rail **3,3 V** de la carte | déduction de la notice |
| Logique UART du radar | 3,3 V des deux côtés → **pas de convertisseur de niveau** | déduction |

## 4. Limites de boîtier

L'issue #5 demande de définir le boîtier : ouverture microphones, fenêtre
écran, façade radar non métallique, ventilation du SHT40. Ce point
**n'est pas résolu** dans cette PR : voici l'état des contraintes à
respecter, à vérifier sur un prototype physique.

| Contrainte | Exigence | Source / déduction |
| --- | --- | --- |
| Ouverture microphones | les deux capsules de l'ES7210 ne doivent pas être bouchées ; pas de coque étanche | déduction du schéma (MIC1/MIC2 sur le bord) |
| Fenêtre écran / façade | l'écran 800×480 doit être dégagé sur toute sa surface | fiche |
| Façade radar | **non métallique** sur toute la zone de rayonnement 24 GHz ; pas de métal, pas de carbone, pas de verre épais | principe radar 24 GHz |
| Ventilation SHT40 | le SHT40 doit mesurer l'**air**, pas la carte : prévoir une grille et ~10–20 cm de câble à l'écart de l'ESP32, de l'écran et du convertisseur | issue #3 + déduction thermique |
| Chaleur | l'écran consomme ~550 mA → le boîtier doit évacuer ; prévoir une entrée d'air non chauffée | déduction |
| Bruit du rail 5 V | écran + radar partagent le rail ; risque d'interférence **audio** à mesurer | issue #3 (« sans perturber la voix ») |
| Connectique | prévoir l'accès au USB-C et au slot TF, et les sorties DI/DO isolées | fiche |
| I/O isolées | DI0/DI1 et DO0/DO1 sont opto-couplées (PC817/PC814) : câblage externe à isolement galvanique | schéma |

## 5. Points non résolus

| Point | État |
| --- | --- |
| Choix du boîtier (référence, dessin, perçages) | **non fait** — contraintes listées ci-dessus |
| BOM **chiffrée** (prix, Références précises des breakout) | **non fait** — les références constructeur ne sont pas toutes uniques (plusieurs revsions du meme module) |
| Câblage à câbler / photos du prototype | **non fait** |
| Tests de coexistence de deux nœuds voisins | **non fait** — demande deux cartes |
| Mesure du bruit du rail 5 V sur la capture micro | **non fait** |
| Choix d'une alimentation 5 V dédiée | **non fait** |
| Température du boîtier en fonctionnement | **non fait** |

## 6. Sources

| Source | URL |
| --- | --- |
| Fiche officielle 4.3C | <https://docs.waveshare.com/ESP32-S3-Touch-LCD-4.3C> |
| Code et schémas officiels | <https://github.com/waveshareteam/ESP32-S3-Touch-LCD-4.3C> |
| Schéma rev. V1.1 | `hardware/schematics/ESP32-S3-Touch-LCD-4.3C-Schematics.pdf` (dépôt officiel) |
| ESPHome `gt911` | <https://esphome.io/components/touchscreen/gt911/> |
| ESPHome `es7210` | <https://esphome.io/components/audio_adc/es7210/> |
| ESPHome `sht4x` | <https://esphome.io/components/sensor/sht4x/> |
| ESPHome `ld2410` | <https://esphome.io/components/sensor/ld2410/> |
| ESPHome `ch422g` | <https://esphome.io/components/ch422g/> |
| ESPHome `mipi_rgb` | <https://esphome.io/components/display/mipi_rgb/> |
| HLK-LD2410C | <https://ld2410.com/ld2410-pinout> (fiche constructeur) |
