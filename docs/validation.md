# Validation et jalons

**État actuel : préparation documentaire. Aucun essai physique ni compilation de la carte cible n'a été rapporté comme réussi.**

## J0 — Compatibilité carte, sans capteurs

- [ ] Vérifier SKU et révision exacte de la carte
- [ ] Extraire brochage et schéma officiel de cette révision
- [ ] Compiler et téléverser un firmware ESPHome minimal ; connexion API sécurisée à Home Assistant
- [ ] Afficher un état stable sur le LCD GC9107
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
