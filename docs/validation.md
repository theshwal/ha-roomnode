# Validation et jalons

**État actuel (2026-11-02) : firmware ESPHome de la cible V1 4.3C compilé et validé statiquement. Aucun essai physique n'a été réalisé — la carte n'a pas été flashée ni observée.**

Ce document distingue trois niveaux, à ne pas confondre :

| Niveau | Commande | Ce que ça prouve |
| --- | --- | --- |
| Schéma | `esphome config` | le YAML est valide et les broches sont libres |
| Compilation | `esphome compile` | le C++ compile et linke pour ESP32-S3 (esp-idf) |
| Essai physique | `esphome run` + `esphome logs` | le comportement réel sur la carte |

Les deux premiers sont **couverts** par `scripts/validate.sh`. Le troisième
**ne l'est pas**.

## Preuves de compilation — cible V1 4.3C (2026-11-02)

Environnement : ESPHome **2026.10.1**, framework `esp-idf` `recommended` résolu
en **ESP-IDF 5.5.6**, cible `esp32s3`, `xtensa-esp32s3-elf-gcc` (GNU 14.2.0),
Python 3.13.5, hôte Linux x86_64.

Commande :

```bash
ESPHOME_COMPILE=1 scripts/validate.sh
```

Résultat : **exit code 0**.

| Profil | Taille image | RAM (DIRAM) | Flash (part. app) |
| --- | ---: | ---: | ---: |
| `43c` (écran RGB 800×480 + GT911 + ES7210 + Assist) | 919 307 o | 110 235 o (32,3 %) | 11,3 % (8 126 464 o) |

Artefacts produits : `firmware.factory.bin`, `firmware.ota.bin`, `firmware.elf`.

Extrait de journal conservé dans le dépôt :
[`docs/build-43c-output.txt`](build-43c-output.txt).

Ce que ces chiffres **ne** prouvent pas : que le firmware démarre, que le
PSRAM est détecté, que le bus I²C répond (GT911 `0x5D`, CH422G, ES7210
`0x40`), que l'écran affiche quoi que ce soit, que le tactile réagit, ni que
le micro capte un signal exploitable. Ces points exigent la carte physique.

### Portée de la CI

La CI GitHub (`.github/workflows/validate-firmware.yml`) lance
`scripts/validate.sh` **sans** `ESPHOME_COMPILE=1` : elle valide donc le
**schéma** des configurations.

Elle **ne compile pas** le firmware. Les tableaux de tailles ci-dessus sont
des **preuves de compilation locales**, obtenues sur la machine de
développement, et ne sont pas des artefacts CI.

## J0 — Compatibilité carte, sans capteurs

- [x] Vérifier SKU et révision exacte de la carte — SKU 33799 (sans boîtier) / 33630 (avec boîtier), schéma rev. V1.1
- [x] Extraire brochage et schéma officiel de cette révision — [gpio-43c.md](gpio-43c.md)
- [x] Firmware ESPHome minimal (socle + écran + tactile + micro) **compilé**
- [ ] Compiler et téléverser le firmware ; connexion API sécurisée à Home Assistant
- [ ] Afficher un état stable sur l'écran RGB 800×480
- [ ] Vérifier le tactile GT911 (5 points)
- [ ] Valider le pilote ES7210 / I²S et la capture audio

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
