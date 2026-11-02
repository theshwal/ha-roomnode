# Validation et jalons

**État actuel : firmware compilé et validé statiquement (2026-11-02). Aucun essai physique n'a été réalisé — la carte n'a pas été flashée ni observée.**

Ce document distingue trois niveaux, à ne pas confondre :

| Niveau | Commande | Ce que ça prouve |
| --- | --- | --- |
| Schéma | `esphome config` | le YAML est valide et les broches sont libres |
| Compilation | `esphome compile` | le C++ compile et linke pour ESP32-S3 (esp-idf) |
| Essai physique | `esphome run` + `esphome logs` | le comportement réel sur la carte |

Les deux premiers sont **couverts** par `scripts/validate.sh` (voir
[flash.md](flash.md)). Le troisième **ne l'est pas**.

## Preuves de compilation (2026-11-02)

Environnement : ESPHome **2026.10.1**, framework `esp-idf` version `recommended`
résolue en **ESP-IDF 5.5.6**, cible `esp32s3`, outil `xtensa-esp32s3-elf-gcc`
(GNU 14.2.0), Python 3.13.5, hôte Linux x86_64.

Commande (secrets factices, aucun `secrets.yaml` lu) :

```bash
ESPHOME_COMPILE=1 scripts/validate.sh
```

Résultat : `exit code 0`, les trois profils compilent.

| Profil | Taille image | RAM (DIRAM) | Flash (part. app) | Artefacts |
| --- | ---: | ---: | ---: | --- |
| `base` (bring-up) | 840 115 o | 106 595 o (31,2 %) | 21,4 % | `firmware.factory.bin`, `firmware.ota.bin`, `firmware.elf` |
| `voice` (micro + Assist) | 898 487 o | 109 143 o (31,9 %) | 22,8 % | idem |
| `display` (écran 0,85″ + LED) | 903 403 o | 111 763 o (32,7 %) | 23,0 % | idem |

Avertissements ESPHome (non bloquants, attendus) :

- `GPIO0 is a strapping pin` — GPIO0 est le bouton BOOT, câblé en pull-up sur
  la carte ; c'est le fonctionnement nominal de l'ESP32-S3.
- `GPIO45 / GPIO46 is a strapping pin` — LCD_DC et LCD_BL sont câblés ainsi sur
  la carte.
- `'ota' password wastes significant flash and RAM` — arbitrage à faire avant
  déploiement (voir [flash.md](flash.md) § 2).

Ce que ces chiffres **ne** prouvent pas : que le firmware démarre, que le
Wi-Fi se connecte, que l'ES7210 répond sur I²C, que le micro capte un signal
exploitable, ni que l'écran affiche quoi que ce soit. Ces points exigent la
carte physique et sont listés en § 7 de [flash.md](flash.md).

## J0 — Compatibilité carte, sans capteurs

- [x] Vérifier SKU et révision exacte de la carte — fiche officielle : SKU 33878 = ESP32-S3-LCD-0.85, SKU 33877 = ESP32-S3-LCD-0.85-**EN**
- [x] Extraire brochage et schéma officiel de cette révision — [gpio.md](gpio.md), sources schematics + BSP officiel
- [x] Firmware ESPHome minimal compilé (profil `base`) et profil micro compilé (profil `voice`)
- [ ] Compiler et téléverser un firmware ESPHome minimal ; connexion API sécurisée à Home Assistant
- [ ] Afficher un état stable sur le LCD GC9107 (profil `display` compilé, rendu non vérifié)
- [ ] Piloter les LEDs WS2812 ; identifier le bouton applicatif sûr
- [ ] Valider pilote ES7210 / I²S et capture audio

**Blocage :** si les micros ne fonctionnent pas avec ESPHome sans développement disproportionné, réexaminer la carte ou le pilote avant d'acheter d'autres unités.

## J1 — Premier dialogue bout en bout (prioritaire)

- [ ] Voix enregistrée sur la carte et reconnue par Assist
- [ ] Mot de réveil local configuré et mesuré
- [ ] Texte de réponse reçu par l'automatisation ESPHome
- [ ] Echo ciblé par pièce, via une entité Alexa Devices Speak, prononce la réponse
- [ ] Gérer l'indisponibilité Echo sans répéter indéfiniment la réponse
- [ ] Tester l'écho acoustique / la détection réentrante
- [ ] Mesurer taux de succès et temps de réponse sur 20 essais

## J2 — Mesures

- [ ] UART LD2410C et alimentation vérifiés avant raccordement
- [ ] Présence mouvement + stationnaire ; réglage des zones et faux positifs
- [ ] SHT40 : température et humidité à comparer à une mesure de référence
- [ ] Chauffe de la carte et erreur de température caractérisées

## J3 — Interface et commande

- [ ] États LCD : prêt / écoute / traitement / erreur, et température
- [ ] États LEDs clairs, intensité réduite la nuit
- [ ] Bouton action courte / longue ; pas de réaffectation risquée de PWR/BOOT
- [ ] Commande déterministe d'un équipement HA et affichage de confirmation
- [ ] Comportement dégradé HA / Amazon / réseau

## J4 — Réplication

- [ ] Configuration commune + paramètres par pièce
- [ ] Documentation de câblage/photo du montage
- [ ] Boîtier et ventilation capteur validés
- [ ] Procédure de provisionnement et OTA
- [ ] Une deuxième unité ne crée pas de double activation vocale gênante

## Définition « terminé V1 »

Un seul module fonctionne durablement en présence humaine et sous usage vocal ordinaire, affiche les mesures, contrôle des actions Home Assistant et renvoie ses réponses sur **l'Echo de la bonne pièce**, sans redémarrages ni fuite de secrets.
