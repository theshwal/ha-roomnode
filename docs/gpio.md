# Tableau GPIO — Waveshare ESP32-S3-LCD-0.85

Toutes les affectations ci-dessous proviennent des **sources officielles Waveshare**, jamais d'un pinout d'une autre carte Waveshare :

| Source | Rôle |
| --- | --- |
| `https://docs.waveshare.com/ESP32-S3-LCD-0.85` | fiche produit, SKU, ressources |
| `https://github.com/waveshareteam/ESP32-S3-LCD-0.85` | dépôt code officiel (exemples Arduino + ESP-IDF) |
| `.../hardware/schematics/ESP32-S3-LCD-0.85-Schematics.pdf` | schéma de référence (source de vérité du câblage) |
| `.../example/ESP-IDF-5.5.1/01_factory/.../components/esp_bsp/bsp_codec.c` | assignation GPIO du BSP officiel |
| `.../example/ESP-IDF-5.5.1/01_factory/.../components/esp_bsp/bsp_display.h` | assignation GPIO de l'écran |
| `.../example/Arduino-3.2.0/examples/01_i2s_audio/01_i2s_audio.ino` | assignation GPIO de l'audio |
| `.../example/Arduino-3.2.0/examples/04_gfx_helloworld/04_gfx_helloworld.ino` | assignation GPIO de l'écran (variante Arduino) |

## Convention

`IOxx` = numéro de GPIO du module ESP32-S3-PICO-1. `GPIOxx` est le nom
equivalent côté ESPHome (`GPIO11` = `IO11`).

## Tableau complet

| GPIO | Fonction officielle | Nettoyage / détail | Utilisé par RoomNode V1 |
| --- | --- | --- | --- |
| IO0 | KEY_MINUS (bouton) | pull-up 10 k (R9), actif à l'état bas | oui — bouton BOOT de la carte ESP32-S3 |
| IO1 | BAT_ADC | pont diviseur VBAT (R27 200 k / R32 100 k) | non (hors V1) |
| IO2 | BAT_EN | mise en marche de la batterie (Q3 AO3401) | non |
| IO3 | CHG_STAT | état du chargeur (ETA6098) | non |
| IO4 | KEY_PLUS (bouton) | pull-up 10 k (R11), actif à l'état bas | oui — bouton PLUS |
| IO5 | KEY_PWR (bouton) | **commande l'alimentation** (Q2 AO3401, T1 8050) | non — bouton d'alimentation, pas un actionneur |
| IO6 | IMU_INT1 | — | non (pas d'IMU sur cette révision) |
| IO7 | PA_CTRL | enable de l'ampli de puissance NS4150 | non — pas de haut-parleur en V1 |
| IO8 | I2S_MCLK | horloge principale du codec | oui — `i2s_mclk_pin` |
| IO9 | I2S_SCLK | BCLK | oui — `i2s_bclk_pin` |
| IO10 | I2S_LRCK | LRCK / WS | oui — `i2s_lrclk_pin` |
| IO11 | I2S_ASDOUT | **SDOUT1 de l'ES7210 → données micro** | oui — `i2s_din_pin` (entrée) |
| IO12 | I2S_DSDIN | DSDIN de l'ES8311 (vers le DAC) | non — pas de restitution locale |
| IO13 | SD_D2 | bus carte TF | non |
| IO14 | SD_D3 | bus carte TF | non |
| IO15 | SD_CMD | bus carte TF | non |
| IO16 | SD_CLK | bus carte TF | non |
| IO17 | SD_D0 | bus carte TF | non |
| IO18 | SD_D1 | bus carte TF | non |
| IO19 | USB_N | USB natif ESP32-S3 | non (réservé USB) |
| IO20 | USB_P | USB natif ESP32-S3 | non (réservé USB) |
| IO21 | LCD_CS | chip select écran | oui — `cs_pin` |
| IO33 | (non exposé) | — | — |
| IO34 | (non exposé) | — | — |
| IO35 | (non exposé) | — | — |
| IO36 | (non exposé) | — | — |
| IO37 | (non exposé) | — | — |
| IO38 | LCD_CLK | SCLK écran | oui — `clk_pin` |
| IO39 | LCD_DIN | MOSI écran | oui — `mosi_pin` |
| IO40 | LCD_RST | reset écran | oui — `reset_pin` |
| IO41 | CODEC_SCL / IMU_SCL / SCL | I²C (pull-up 4,7 k R15) | oui — `scl` bus I²C codec |
| IO42 | CODEC_SDA / IMU_SDA / SDA | I²C (pull-up 4,7 k R22) | oui — `sda` bus I²C codec |
| IO43 | ESP_TXD | UART de debug (console ESPHome) | oui — console UART |
| IO44 | ESP_RXD | UART de debug | oui — console UART |
| IO45 | LCD_DC | D/C écran | oui — `dc_pin` |
| IO46 | LCD_BL | rétroéclairage (LEDC) | oui — `enable_pin` / rétroéclairage |
| IO47 | IMU_INT2 | — | non |
| IO48 | WS2812_DI | **data des 8 LEDs RGB** | oui — `neopixel` (optionnel) |

## Sous-ensembles utilisés en V1 et contrôle de collision

| Sous-ensemble | GPIO utilisés | Collision |
| --- | --- | --- |
| I²C codec (ES7210 @ 0x40, ES8311 @ 0x18) | 41, 42 | aucune |
| I²S (réception micro) | 8, 9, 10, 11 | aucune |
| Boutons | 0, 4 | aucune |
| LCD (GC9107) | 21, 38, 39, 40, 45, 46 | aucune |
| WS2812 | 48 | aucune |
| Extension (radar LD2410C, SHT40) | pads I²C / UART libres | à fixer au câblage physique |

Aucun GPIO n'est attribué deux fois dans le firmware livré.

## Câblage micro — détail vérifié

Schéma officiel, section codec :

- `ES7210.SDOUT1` (broche 11) → net `I2S_ASDOUT` → `IO11`.
  `ES7210.SDOUT2` (broche 12) → net `I2S_DSDIN` → `IO12` : **c'est le DAC
  ES8311**, pas un second flux micro.
- L'ES7210 est câblé en TDM : SDOUT1 transporte MIC1+MIC2, SDOUT2 transporte
  MIC3+MIC4.
- Les deux microphones de la carte (MIC1, MIC2) sont câblés en différentiel
  sur `MIC1_P/MIC1_N` et `MIC2_P/MIC2_N`, alimentés par `ADC_MICBIAS12`.
- `MIC3`/`MIC4` ne sont pas câblés sur cette carte (seuls 2 micros physiques).

Le pilote ESPHome `es7210` ne gère pas le TDM (`enable_tdm_ = false` dans
`es7210.h`) : il lit SDOUT1, donc MIC1+MIC2. La source micro sélectionne le
canal 0 (MIC1).

## Contraintes à respecter

- **Alimentation :** l'ES8311 et le NS4150 sont alimentés en 3,3 V. L'ES7210
  aussi. Ne jamais injecter de 5 V logique.
- **PA_CTRL (IO7) :** laisser ce GPIO non configuré. Il commande l'ampli de
  puissance ; l'activer sans haut-parleur branché n'apporte rien et
  consomme du courant.
- **KEY_PWR (IO5) :** bouton d'alimentation. Le piloter comme un actionneur
  pourrait couper l'alimentation de la carte.
- **USB (IO19/IO20) :** ne pas les réutiliser, la console ESPHome passe par là.
- **IO0 :** c'est un *strapping pin* (boot). ESPHome émet un avertissement
  explicite ; le bouton BOOT est câblé en pull-up, ce qui est le
  fonctionnement normal de la carte.

## Références obsolètes à ne pas réutiliser

Le tableau « GPIO » publié sur `docs.waveshare.com` correspond à une
**autre** numérotation que celle de cette carte (il y associe par exemple
`IO45` à `LCD DC` et `IO46` à `LCD BL`, ce qui est cohérent ici, mais place
`KEY_MINUS` sur `IO0` et `KEY_PLUS` sur `IO4` et `KEY_PWR` sur `IO5`, ce qui
est également cohérent). **La référence utilisée ici reste le schéma PDF
officiel + le BSP officiel**, qui sont concordants entre eux et avec le code
démo.

## Références SKU corrigées

Fiche officielle `docs.waveshare.com/ESP32-S3-LCD-0.85` :

| SKU | Produit |
| --- | --- |
| **33878** | ESP32-S3-LCD-0.85 |
| **33877** | ESP32-S3-LCD-0.85-**EN** |

L'ancienne documentation du dépôt affirmait « SKU 33877 sans batterie » :
c'est **erroné**. La fiche officielle ne distingue pas « avec / sans
batterie » pour ces deux SKU ; elle indique seulement le suffixe `-EN`. Ne pas
affirmer un lien entre SKU et présence de batterie sans source explicite.
