# Matériel et interfaces — HA RoomNode V1

## Carte de référence

**Waveshare ESP32-S3-Touch-LCD-4.3C**, SKU **33799** (sans boîtier) ou
**33630** (avec boîtier plastique).

Caractéristiques publiées par le fabricant : ESP32-S3-WROOM-1-**N16R8**
(16 Mo flash / 8 Mo PSRAM), écran tactile capacitif **800×480** (RGB 16 bits,
contrôleur **GT911** 5 points), codec **ES8311** (DAC) et **ES7210** (ADC
micro 4 canaux), ampli **NS4150**, horloge **PCF85063**, expander I²C
**CH422G**, entrées/sorties **DI/DO isolées**, emplacement TF, USB-C, boutons
BOOT et RST.

Source : https://www.waveshare.com/product/esp32-s3-touch-lcd-4.3c.htm
Doc : https://docs.waveshare.com/ESP32-S3-Touch-LCD-4.3C
Code et schémas : https://github.com/waveshareteam/ESP32-S3-Touch-LCD-4.3C
Schéma : `hardware/schematics/ESP32-S3-Touch-LCD-4.3C-Schematics.pdf` (rev. V1.1)

Le tableau GPIO complet et sourcé est dans [gpio-43c.md](gpio-43c.md).

**Prototype historique.** La **ESP32-S3-LCD-0.85** (SKU 33878 =
ESP32-S3-LCD-0.85, SKU 33877 = ESP32-S3-LCD-0.85-**EN**) a servi de PoC
firmware : son code est maintenu sur `feature/issue-1-esphome-bringup`
(PR #8, draft). *Note : une version antérieure de ce document affirmait
« SKU 33877 sans batterie » ; c'est erroné, la fiche officielle ne distingue
que le suffixe `-EN`.* Elle n'est plus la carte V1.

**Attention :** la présence de codecs et microphones ne prouve pas que leur
pilote ESPHome fonctionne immédiatement. Vérifier aussi le support du
tactile GT911, du CH422G, des entrées/sorties isolées et la révision de la
carte avant d'assigner les GPIO.

## Liste V1

| Référence | Qté | Interface | Statut |
| --- | ---: | --- | --- |
| Waveshare ESP32-S3-Touch-LCD-4.3C, SKU 33799 | 1 | USB-C / GPIO internes | Choisie, intégration firmware à valider |
| HLK-LD2410C radar présence | 1 | UART | Choisi, tension d'alimentation à vérifier avant branchement |
| SHT40 (température + humidité) sur module | 1 | I²C, 3,3 V suivant breakout | Choisi |
| Chargeur USB-C et câble données | 1 | USB-C | Réutiliser existant si adapté |
| Fils de liaison, connecteurs et éventuellement adaptateur 5 V | selon montage | GPIO / alimentation | Selon plan de câblage |

Options **différées** : BH1750 luminosité (I²C), SCD40 CO₂ (I²C), IR. Pas de capteurs PM/COV/NOx en V1.

## Risques matériels à lever AVANT de souder

1. **Alimentation radar** : LD2410C doit recevoir une tension conforme à sa fiche technique (habituellement 5 V) ; ne pas supposer que la carte fournit 5 V sur ses pads d'extension. Vérifier le schéma et prévoir si besoin une dérivation du 5 V USB.
2. **Niveaux logiques** : vérifier les tensions UART du LD2410C et du contrôleur ESP32-S3 (3,3 V). Aucune broche ESP ne doit recevoir du 5 V logique.
3. **Brochage exact** : le tableau GPIO est extrait du schéma officiel de la variante achetée (voir [gpio-43c.md](gpio-43c.md)) ; les collisions entre I²C, UART, audio I²S, RGB et CH422G sont contrôlées.
4. **Alimentation de l'écran** : l'écran 800×480 consomme ~550 mA. Le schéma de la 4.3C prévoit une alimentation 5 V dédiée (`DC_5V`, TMI3112H) et un convertisseur 5 V (SY8293FCC) avec un sélecteur de source (`PWR`). Le schéma signale que la sortie USB d'un PC peut être insuffisante (< 500 mA). Vérifier l'alimentation **avant** de conclure à un défaut d'affichage ou de tactile.
5. **Niveaux logiques** : vérifier les tensions UART du LD2410C et du contrôleur ESP32-S3 (3,3 V). Aucune broche ESP ne doit recevoir du 5 V logique.
6. **Thermique** : éloigner le SHT40 de l'ESP32, de l'écran, de l'alimentation et d'un éventuel chargeur ; prévoir une entrée d'air non chauffée.
7. **Radar** : façade non métallique adaptée, orientation/positionnement et absence de vibrations ; tester les fausses détections.
8. **Acoustique** : ouvertures face au micro de l'ES7210, espacement vis-à-vis des haut-parleurs et de l'écran, absence de son parasite.
9. **Fiabilité** : alimentation permanente USB-C, pas de batterie pour la V1.

## Achat

Ne pas acheter en lot avant le premier test voix. Les liens Amazon de recherche ne suffisent pas à confirmer un article : vérifier **référence exacte, photos, SKU et brochage** auprès du fabricant.

## Conditions de passage à la fabrication

- Une session complète mot de réveil → transcription → réponse Alexa fonctionne.
- Les capteurs fournissent des valeurs cohérentes sans perturber la voix.
- L'écran et les LEDs restent réactifs.
- Le prototype ne redémarre pas sous charge.
