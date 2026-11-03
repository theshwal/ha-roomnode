# Tableau GPIO — Waveshare ESP32-S3-Touch-LCD-4.3C (cible V1)

Carte : **ESP32-S3-Touch-LCD-4.3C**, module ESP32-S3-WROOM-1-**N16R8**
(16 Mo flash / 8 Mo PSRAM octal).
SKU : **33799** (sans boîtier) / **33630** (avec boîtier plastique).

## Sources

| # | Source | Ce qui en est tiré |
| --- | --- | --- |
| 1 | `https://docs.waveshare.com/ESP32-S3-Touch-LCD-4.3C` | SKU, caractéristiques, tables de correspondance GPIO (LCD / Touch / TF / RTC / I²C / Codec) |
| 2 | `https://github.com/waveshareteam/ESP32-S3-Touch-LCD-4.3C` → `hardware/schematics/ESP32-S3-Touch-LCD-4.3C-Schematics.pdf` (rev. **V1.1**) | schéma de référence : nets `I2S_*`, `LCD_*`, `CODEC_*`, `CTP_*`, table ESP32-S3 ↔ connecteur PORT1 (40 broches) |
| 3 | ESPHome `components/mipi_rgb/models/waveshare.py` → modèle `ESP32-S3-TOUCH-LCD-4.3` | `data_pins` R/G/B, `de_pin`, `hsync_pin`, `vsync_pin`, `pclk_pin`, porches, reset (CH422G pin 3), enable (CH422G pin 2), `requires={"psram","ch422g"}` |
| 4 | ESPHome `components/gt911` | contrôleur tactile capacitif, adresse I²C `0x5D`, IRQ + reset optionnels |
| 5 | ESPHome `components/ch422g` | expander I²C de la carte (reset écran, rétroéclairage, PA_CTRL, CS TF) |

Les sources 1, 2 et 3 sont **concordantes** entre elles : le modèle ESPHome
préfabriqué reproduit exactement le câblage du schéma officiel Waveshare.

## Tableau GPIO

### Écran RGB 800×480 (interface 16 bits)

| Signal LCD | Net schéma | GPIO ESP32-S3 |
| --- | --- | --- |
| R3 | `R3` | GPIO1 |
| R4 | `R4` | GPIO2 |
| R5 | `R5` | GPIO42 |
| R6 | `R6` | GPIO41 |
| R7 | `R7` | GPIO40 |
| G2 | `G2` | GPIO39 |
| G3 | `G3` | GPIO0 |
| G4 | `G4` | GPIO45 |
| G5 | `G5` | GPIO48 |
| G6 | `G6` | GPIO47 |
| G7 | `G7` | GPIO21 |
| B3 | `B3` | GPIO14 |
| B4 | `B4` | GPIO38 |
| B5 | `B5` | GPIO18 |
| B6 | `B6` | GPIO17 |
| B7 | `B7` | GPIO10 |
| PCLK | `PCLK` (inversée) | GPIO7 |
| HSYNC | `HSYNC` | GPIO46 |
| VSYNC | `VSYNC` | GPIO3 |
| DE | `DE` | GPIO5 |
| Reset écran | `LCD_RST` | **CH422G pin 3** (EXIO2) |
| Rétroéclairage | `DISP` / `EXIO_PWM` | **CH422G pin 2** (EXIO2) |

### Tactile capacitif GT911

| Signal | Net schéma | GPIO |
| --- | --- | --- |
| SDA | `CTP_SDA` / `D_SDA` | GPIO8 |
| SCL | `CTP_SCL` / `D_SCL` | GPIO9 |
| IRQ | `CTP_IRQ` | GPIO4 |
| Reset | `CTP_RST` | **CH422G pin 1** (EXIO1) |

Le GT911 est à l'adresse I²C `0x5D` (ESPHome `gt911`, par défaut). Il partage
le bus I²C unique de la carte.

### Audio (ES7210 + ES8311 + NS4150)

| Signal | Net schéma | GPIO |
| --- | --- | --- |
| I²S MCLK | `I2S_MCLK` | GPIO6 |
| I²S SCLK | `I2S_SCLK` | GPIO44 |
| I²S LRCK | `I2S_LRCK` | GPIO16 |
| I²S ASDOUT (données **micro**) | `I2S_ASDOUT` (SDOUT1 de l'ES7210) | GPIO43 — **entrée ESP32** |
| I²S DSDIN (vers DAC) | `I2S_DSDIN` (DSDIN de l'ES8311) | GPIO15 — TX ESP32, non utilisé |
| I²S SDA (codec) | `Audio_SDA` | GPIO8 (bus I²C partagé) |
| I²S SCL (codec) | `Audio_SCL` | GPIO9 (bus I²C partagé) |
| Enable ampli | `PA_CTRL` | **CH422G pin 4** (EXIO4) — non activé en V1 |

Adresses I²C : ES7210 = `0x40`, ES8311 = `0x18`, GT911 = `0x5D`.

### Divers

| Fonction | GPIO |
| --- | --- |
| TF card MOSI / SCK / MISO | GPIO11 / GPIO12 / GPIO13 |
| TF card CS | CH422G pin 4 (EXIO4, partagé avec PA_CTRL) |
| USB natif | GPIO19 / GPIO20 |
| RTC PCF85063 SDA / SCL | GPIO8 / GPIO9 (bus I²C partagé) |
| DI0 / DI1 (entrées isolées) | CH422G (EXIO0 / EXIO5) |
| DO0 / DO1 (sorties isolées) | CH422G (EXIO6 / EXIO7) |
| Reset écran / backlight / PA_CTRL / CS TF | CH422G pins 3 / 2 / 4 / 4 |

## Contrôle de collision (profil livré)

| Sous-ensemble | GPIO / pins CH422G utilisés | Collision |
| --- | --- | --- |
| I²C (GT911, CH422G, ES7210, ES8311, RTC) | 8, 9 | aucune |
| I²S (réception micro) | 6, 44, 16, 43 | aucune |
| Tactile | 4 | aucune |
| RGB écran | 0, 1, 2, 5, 7, 10, 14, 17, 18, 21, 38, 39, 40, 41, 42, 45, 46, 47, 48 | aucune |
| CH422G | 1 (reset tactile), 2 (backlight), 3 (reset écran) | aucune |

Le GPIO15 (`I2S_DSDIN`, TX vers l'ES8311) et GPIO11/12/13 (TF) restent libres
car ces fonctions ne sont pas activées dans le profil livré.

## Contraintes à respecter

- **PSRAM obligatoire** : le tampon d'affichage 800×480 ne tient pas en RAM
  interne. `psram: mode: octal` est requis, et le modèle ESPHome déclare
  `requires={"psram", "ch422g"}` — la validation échoue si l'un manque.
- **16 Mo de flash** : la carte est en N16R8. `flash_size: 16MB`.
- **Strapping pins** : GPIO0 (G3), GPIO3 (VSYNC), GPIO45 (G4), GPIO46 (HSYNC)
  sont des pins de strapping. Le modèle ESPHome passe `ignore_strapping_warning`
  sur `hsync_pin` et `vsync_pin`. Ne pas y attacher de pull-up externe.
- **Alimentation** : l'écran consomme ~550 mA. Le schéma prévoit une
  alimentation 5 V dédiée (TMI3112H, `DC_5V`) et un(boost) 5 V (SY8293FCC)
  avec le sélecteur de source (`PWR`). L'USB d'un PC peut ne pas suffire :
  voir la note du schéma « Low output (<500 mA) computer USB ».
- **Pas de haut-parleur en V1** : l'ES8311 et le NS4150 ne sont pas activés,
  `PA_CTRL` (CH422G pin 4) reste non piloté. La voix sortante passe par
  l'Echo de la pièce.
- **I²C unique** : GT911, CH422G, ES7210, ES8311 et RTC partagent GPIO8/GPIO9.
  Un conflit d'adresse ou une longue ligne peut empêcher le scan.

## Non vérifié physiquement

Aucune des vérifications suivantes n'a été faite sur la carte : boot, PSRAM,
scan I²C, affichage RGB, tactile GT911, capture micro ES7210, pipeline Assist.
Le tableau ci-dessus est **documentaire** (schéma + fiche officielle + modèle
ESPHome), pas **expérimental**.
