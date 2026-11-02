# HA RoomNode

Terminal domotique de pièce sous **ESPHome + Home Assistant** : écouter, mesurer la présence et l'ambiance, piloter les équipements et fournir des retours visuels. La réponse vocale passe par l'**Amazon Echo déjà présent dans la pièce** ; RoomNode n'a pas besoin de haut-parleur.

> **Statut (2026-11-02) : firmware ESPHome livré et compilé, pas encore essayé sur la carte.** Les profils `base`, `voice` et `display` passent `esphome config` **et** `esphome compile` (esp-idf). Aucun flash ni essai physique n'a été réalisé : ne pas considérer le firmware comme validé sur matériel.

## Firmware

| Fichier | Rôle |
| --- | --- |
| `firmware/roomnode-common.yaml` | socle : plateforme ESP32-S3, Wi-Fi, API chiffrée, OTA, PSRAM, boutons |
| `firmware/roomnode-base.yaml` | profil **bring-up** minimal (socle seul) |
| `firmware/roomnode-voice.yaml` | profil **micro + Assist** (ES7210 + I²S + `voice_assistant`) |
| `firmware/roomnode-display-085.yaml` | package **affichage 0,85″** isolé et remplaçable (GC9107 + WS2812) |
| `firmware/roomnode-display.yaml` | profil affichage (socle + package 0,85″) |
| `scripts/validate.sh` | validation statique + compilation, à secrets fictifs |
| `secrets.example.yaml` | modèle de secrets (valeurs factices) |

Installation, flash et plan de test : [docs/flash.md](docs/flash.md).

## V1 — périmètre décidé

| Fonction | Choix |
| --- | --- |
| Carte | Waveshare **ESP32-S3-LCD-0.85**, SKU **33878** (ou 33877 **-EN**), ESP32-S3 N8R8 |
| Voix entrante | Microphones de la carte → ESPHome Voice Assistant → Home Assistant Assist |
| Voix sortante | Texte de réponse Assist → Home Assistant **Alexa Devices** → entité notify Speak de l'Echo de la même pièce |
| Présence | Radar **HLK-LD2410C** (UART), présence y compris stationnaire |
| Température / humidité | **SHT40** sur I²C (un capteur, deux mesures) |
| Interface | LCD 0,85″ 128×128 (GC9107), 8 LEDs RGB, boutons présents sur la carte |
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
- [Tableau GPIO sourcé](docs/gpio.md)
- [Installation, flash et plan de test](docs/flash.md)
- [Plan de validation](docs/validation.md)

## Premier jalon (bloquant)

Faire reconnaître **les microphones de la Waveshare par ESPHome** et obtenir un pipeline Assist stable. Vérifier ensuite qu'un texte issu d'Assist est envoyé à l'Echo associé via **Alexa Devices**. Les fonctions de capteurs, LCD et boîtier viennent ensuite.

## Sources de référence

- [Carte Waveshare ESP32-S3-LCD-0.85 — fabricant](https://www.waveshare.com/product/esp32-s3-lcd-0.85.htm)
- [Documentation Waveshare](https://docs.waveshare.com/ESP32-S3-LCD-0.85)
- [Code et schémas officiels Waveshare](https://github.com/waveshareteam/ESP32-S3-LCD-0.85)
- [ESPHome Voice Assistant](https://esphome.io/components/voice_assistant/)
- [ESPHome Micro Wake Word](https://esphome.io/components/micro_wake_word/)
- [ESPHome API / actions Home Assistant](https://esphome.io/components/api/)
- [Home Assistant Alexa Devices](https://www.home-assistant.io/integrations/alexa_devices/)

Les fiches Amazon précédemment citées ne constituent **pas** une nomenclature validée ; acheter selon la référence fabricant exacte et les contraintes électriques décrites dans le dossier matériel.
