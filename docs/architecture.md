# Architecture — HA RoomNode V1

## Parcours de commande

1. La carte Waveshare capture la voix avec ses microphones.
2. ESPHome effectue, après validation du support audio, la détection du mot de réveil (Micro Wake Word) et transmet l'audio à Home Assistant Assist.
3. Home Assistant traite la transcription avec un agent conversationnel sélectionné ; les automatismes de la maison restent, autant que possible, déterministes.
4. Le texte de réponse est disponible dans l'événement ESPHome Voice Assistant « on_tts_start » (même sans haut-parleur local, avec une étape TTS configurée dans le pipeline).
5. ESPHome appelle une action Home Assistant autorisée ; HA route le texte vers l'entité Speak de l'Echo de la même pièce avec « notify.send_message ».
6. Le LCD et les LEDs indiquent les étapes : prêt, écoute, traitement, réponse, erreur.

**Ce schéma est documenté, mais la chaîne complète Waveshare → ESPHome → Assist → Alexa n'a pas été éprouvée physiquement.**

## Règles de répartition

- Chaque nœud a un identifiant stable et une zone Home Assistant.
- Chaque zone définit l'Echo Speak associé ; ne pas envoyer les réponses à « dernier Echo utilisé ».
- Éviter de laisser le nœud capter la réponse prononcée par Alexa : suspendre/temporiser le réveil durant la restitution. L'API Alexa ne donne pas nécessairement un signal fiable de fin de parole ; un délai est une solution imparfaite.
- Deux modules proches peuvent capter le même mot de réveil. Commencer par réglage sensibilité / placement ; arbitrage global seulement si nécessaire.
- L'absence de réponse Alexa ne doit pas bloquer une commande Home Assistant déjà exécutée.
- En cas de perte d'accès au cloud Amazon : état et confirmation à l'écran, commandes physiques toujours disponibles selon la connexion à HA.

## Confidentialité et sécurité

- Pas de clés Wi-Fi, tokens ESPHome/HA, comptes Amazon ou IP privées dans ce dépôt public.
- Un interrupteur de coupure *matérielle* du microphone reste une **exigence à étudier** ; la carte n'en garantit pas l'existence.
- La reconnaissance initiale via ESPHome/Assist peut être locale selon les services configurés ; la restitution sur Echo **dépend du cloud Amazon**.
- Ne pas enregistrer systématiquement les transcriptions ou l'audio des pièces.
- Le déclenchement d'actions Home Assistant depuis ESPHome nécessite une autorisation explicite pour ce nœud dans l'intégration ESPHome.

## Évolutivité sans services supplémentaires

- Une configuration de base commune ESPHome et des substitutions légères par pièce.
- Scripts/automatisations Home Assistant pour les règles domotiques et le routage Echo.
- Pas de broker supplémentaire, pas de serveur spécifique, pas d'agent LLM embarqué.
- Boutons, LCD et LEDs doivent rester utiles sans réponse conversationnelle.

## Documentation officielle

- https://esphome.io/components/voice_assistant/
- https://esphome.io/components/micro_wake_word/
- https://esphome.io/components/api/
- https://www.home-assistant.io/integrations/alexa_devices/
