# Matériel et interfaces — HA RoomNode V1

## Carte de référence

**Waveshare ESP32-S3-LCD-0.85** — SKU **33878** = ESP32-S3-LCD-0.85,
SKU **33877** = ESP32-S3-LCD-0.85-**EN**.

> **Correction (2026-11-02).** Une version antérieure de ce document affirmait
> « SKU 33877 sans batterie (33878 avec batterie) ». C'est **erroné** : la
> fiche officielle `docs.waveshare.com/ESP32-S3-LCD-0.85` distingue uniquement
> le suffixe `-EN`. Ne pas associer un SKU à la présence d'une batterie sans
> source explicite du fabricant.

Caractéristiques publiées par le fabricant : ESP32-S3-PICO-1-N8R8 (8 Mo flash / 8 Mo PSRAM), écran IPS 0,85″ 128×128 (GC9107, SPI), **deux microphones**, codecs ES7210 / ES8311, **8 LEDs WS2812 RGB**, ports d'extension I²C/UART, USB-C, boutons PLUS, BOOT et PWR (ce dernier commande l'alimentation et ne doit pas être assimilé sans test à un bouton applicatif ordinaire).

Source : https://www.waveshare.com/product/esp32-s3-lcd-0.85.htm
Doc : https://docs.waveshare.com/ESP32-S3-LCD-0.85
Code officiel : https://github.com/waveshareteam/ESP32-S3-LCD-0.85
Schéma : `hardware/schematics/ESP32-S3-LCD-0.85-Schematics.pdf` (dépôt officiel)

**Attention :** la présence de codecs et microphones ne prouve pas que leur pilote ESPHome fonctionne immédiatement. Vérifier aussi le support du GC9107, des WS2812, des boutons et la révision de la carte avant d'assigner les GPIO.

Le **tableau GPIO complet et sourcé** est dans [gpio.md](gpio.md).

## Liste V1

| Référence | Qté | Interface | Statut |
| --- | ---: | --- | --- |
| Waveshare ESP32-S3-LCD-0.85, SKU 33878 (ou 33877 -EN) | 1 | USB-C / GPIO internes | Choisie, intégration firmware à valider |
| HLK-LD2410C radar présence | 1 | UART | Choisi, tension d'alimentation à vérifier avant branchement |
| SHT40 (température + humidité) sur module | 1 | I²C, 3,3 V suivant breakout | Choisi |
| Chargeur USB-C et câble données | 1 | USB-C | Réutiliser existant si adapté |
| Fils de liaison, connecteurs et éventuellement adaptateur 5 V | selon montage | GPIO / alimentation | Selon plan de câblage |

Options **différées** : BH1750 luminosité (I²C), SCD40 CO₂ (I²C), IR. Pas de capteurs PM/COV/NOx en V1.

## Risques matériels à lever AVANT de souder

1. **Alimentation radar** : LD2410C doit recevoir une tension conforme à sa fiche technique (habituellement 5 V) ; ne pas supposer que la carte fournit 5 V sur ses pads d'extension. Vérifier le schéma et prévoir si besoin une dérivation du 5 V USB.
2. **Niveaux logiques** : vérifier les tensions UART du LD2410C et du contrôleur ESP32-S3 (3,3 V). Aucune broche ESP ne doit recevoir du 5 V logique.
3. **Brochage exact** : faire un tableau GPIO extrait du schéma officiel de la variante achetée ; contrôler les collisions entre I²C, UART, audio I²S, LCD, LEDs et boutons.
4. **Thermique** : éloigner le SHT40 de l'ESP32, de l'écran, de l'alimentation et d'un éventuel chargeur ; prévoir une entrée d'air non chauffée.
5. **Radar** : façade non métallique adaptée, orientation/positionnement et absence de vibrations ; tester les fausses détections.
6. **Acoustique** : ouvertures face aux micros, espacement vis-à-vis des LEDs/écran et absence de son parasite.
7. **Fiabilité** : alimentation permanente USB-C, pas de batterie pour la V1.

## Achat

Ne pas acheter en lot avant le premier test voix. Les liens Amazon de recherche ne suffisent pas à confirmer un article : vérifier **référence exacte, photos, SKU et brochage** auprès du fabricant.

## Conditions de passage à la fabrication

- Une session complète mot de réveil → transcription → réponse Alexa fonctionne.
- Les capteurs fournissent des valeurs cohérentes sans perturber la voix.
- L'écran et les LEDs restent réactifs.
- Le prototype ne redémarre pas sous charge.
