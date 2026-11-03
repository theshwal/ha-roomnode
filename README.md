# HA RoomNode

Terminal domotique de pièce sous **ESPHome + Home Assistant** : écouter, mesurer la présence et l'ambiance, piloter les équipements et fournir des retours visuels. La réponse vocale passe par l'**Amazon Echo déjà présent dans la pièce** ; RoomNode n'a pas besoin de haut-parleur.

> **Statut (2026-11-02) : firmware ESPHome de la cible V1 compilé et validé statiquement. Aucun essai physique.** Le profil `43c` passe `esphome config` **et** `esphome compile` (esp-idf). La carte n'a pas été flashée : ne pas considérer le firmware comme validé sur matériel.

> **Carte cible V1 : Waveshare ESP32-S3-Touch-LCD-4.3C** (tactile capacitif
> 800×480, GT911, ES7210, ES8311), actée par les issues **#1 / #4 / #7**.
> SKU **33799** (sans boîtier) / **33630** (avec boîtier plastique).
> La **ESP32-S3-LCD-0.85** reste un **prototype historique** : son firmware
> de référence est maintenu sur la branche `feature/issue-1-esphome-bringup`
> (PR #8, draft).

## V1 — périmètre décidé

| Fonction | Choix |
| --- | --- |
| Carte | Waveshare **ESP32-S3-Touch-LCD-4.3C** (tactile 800×480, GT911, ES7210, ES8311), ESP32-S3 N16R8 |
| Voix entrante | Microphone ES7210 → ESPHome Voice Assistant → Home Assistant Assist |
| Voix sortante | Texte de réponse Assist → Home Assistant **Alexa Devices** → entité notify Speak de l'Echo de la même pièce |
| Présence | Radar **HLK-LD2410C** (UART), présence y compris stationnaire |
| Température / humidité | **SHT40** sur I²C (un capteur, deux mesures) |
| Interface | Écran tactile capacitif 800×480 + GT911, RTC PCF85063, entrées/sorties isolées |
| Connectivité | Wi-Fi local + API ESPHome |
| Options différées | BH1750 (luminosité), SCD40 (CO₂), infrarouge, fonctions réseau additionnelles |
| Hors V1 | e-paper, PM/COV/NOx, répéteur Wi-Fi, Bluetooth Proxy, haut-parleur interne |

## Principes

1. **Home Assistant décide et orchestre** : automatisations et commandes déterministes en priorité ; agent conversationnel si nécessaire.
2. **Un firmware configurable par pièce** : nom, zone Home Assistant, Echo de sortie, fonctions activées.
3. **Aucun secret dans GitHub** : clés API, Wi-Fi, comptes Amazon, URL privées restent dans les secrets locaux.
4. **Pas de sur-ingénierie** : pas de service autonome, ni orchestrateur supplémentaire, ni intégration Amazon personnalisée.
5. **Priorité à la qualité vocale** : ne pas cumuler d'emblée micro wake word + Bluetooth Proxy + répéteur.
6. **Confort et confidentialité** : couper ou inhiber l'écoute pendant la réponse Alexa ; coupure matérielle micro à étudier, non présumée intégrée.
7. **Interchangeabilité** : conserver un mode visuel/commandes locales lorsque les services vocaux/cloud sont indisponibles.

## Documents

- [Architecture et interactions](docs/architecture.md)
- [Matériel, interfaces et achats](docs/hardware.md)
- [Tableau GPIO de la cible V1 4.3C](docs/gpio-43c.md)
- [Installation, flash et plan de test 4.3C](docs/flash-43c.md)
- [Capteurs SHT40 + LD2410C (issue #3)](docs/sensors-43c.md)
- [Plan de validation](docs/validation.md)

## Firmware

| Fichier | Rôle |
| --- | --- |
| `firmware/roomnode-43c-common.yaml` | socle V1 : ESP32-S3 N16R8, esp-idf, Wi-Fi, API chiffrée, OTA, PSRAM octal |
| `firmware/roomnode-43c.yaml` | cible V1 : I²C unique, CH422G, écran RGB 800×480, tactile GT911, micro ES7210 + `voice_assistant` |
| `firmware/roomnode-43c-sensors.yaml` | package capteurs (issue #3) : SHT40 I²C + radar LD2410C UART |
| `firmware/roomnode-43c-full.yaml` | profil complet V1 + capteurs |
| `scripts/validate.sh` | validation statique + compilation, à valeurs fictices, sans secret |
| `secrets.example.yaml` | modèle de secrets (valeurs factices) |

## Premier jalon (bloquant)

Faire reconnaître **le microphone ES7210 de la 4.3C par ESPHome** et obtenir
un pipeline Assist stable. Vérifier ensuite qu'un texte issu d'Assist est
envoyé à l'Echo associé via **Alexa Devices**. Les fonctions de capteurs et
boîtier viennent ensuite.

## Sources de référence

- [Carte Waveshare ESP32-S3-Touch-LCD-4.3C — fabricant](https://www.waveshare.com/product/esp32-s3-touch-lcd-4.3c.htm)
- [Documentation Waveshare 4.3C](https://docs.waveshare.com/ESP32-S3-Touch-LCD-4.3C)
- [Code et schémas officiels 4.3C](https://github.com/waveshareteam/ESP32-S3-Touch-LCD-4.3C)
- [Prototype historique 0,85″ — doc Waveshare](https://docs.waveshare.com/ESP32-S3-LCD-0.85)
- [ESPHome Voice Assistant](https://esphome.io/components/voice_assistant/)
- [ESPHome Micro Wake Word](https://esphome.io/components/micro_wake_word/)
- [ESPHome API / actions Home Assistant](https://esphome.io/components/api/)
- [Home Assistant Alexa Devices](https://www.home-assistant.io/integrations/alexa_devices/)

Les fiches Amazon précédemment citées ne constituent **pas** une nomenclature validée ; acheter selon la référence fabricant exacte et les contraintes électriques décrites dans le dossier matériel.
