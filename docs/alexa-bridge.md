# Pont vocal Assist → Amazon Echo (issue #2)

## Fonctionnement

1. La Waveshare/ESPHome capte l'audio **par ses microphones dédiés**.
2. Home Assistant Assist assure STT → intention → réponse texte.
3. `voice_assistant.on_tts_start` expose ce texte via la variable `x` (la chaîne ne nécessite pas de haut-parleur local, mais une étape TTS configurée dans Assist).
4. ESPHome lance `script.roomnode_speak` avec **l'identifiant stable du module** et le texte reçu.
5. Le script Home Assistant associe l'identifiant à **une entité Speak** de l'intégration officielle Alexa Devices et appelle `notify.send_message`.

## Fichiers

- [Exemple ESPHome à intégrer dans le firmware](../esphome/examples/voice_to_alexa.yaml)
- [Package Home Assistant d'exemple](../homeassistant/packages/roomnode.yaml)

## Déploiement dans Home Assistant

1. Installer et configurer l'intégration **Alexa Devices** (authentification multifacteur Amazon requise).
2. Vérifier que l'Echo cible possède une entité `notify.*_speak` et que l'action **notify.send_message** fonctionne manuellement sur cette entité.
3. Mettre le package d'exemple sous `/config/packages/roomnode.yaml` puis activer les packages si besoin dans `configuration.yaml` :

    ```yaml
    homeassistant:
      packages: !include_dir_named packages
    ```

4. Modifier **uniquement localement** `echo_by_roomnode` dans le package, par exemple `roomnode_salon: notify.MON_ECHO_speak`, en utilisant les vraies entités constatées dans HA. La clé doit correspondre au `node_name` du nœud (voir ci-dessous).
5. Redémarrer Home Assistant après contrôle de configuration (ou recharger les scripts selon le mode de déploiement).
6. Dans **Outils de développement → Actions**, exécuter `script.roomnode_speak` avec `roomnode: roomnode_salon` et `message: Bonjour`. La réponse doit venir uniquement de l'Echo correspondant.
7. Sur la fiche de l'appareil ESPHome dans Home Assistant, autoriser **Allow the device to perform Home Assistant actions** ; sans cela `homeassistant.action` est refusé.
8. Intégrer le bloc de l'exemple ESPHome au firmware matériel, en remplaçant `roomnode_microphone` par l'ID réel du microphone et en définissant la substitution `node_name`.

## Identifiant de nœud : une substitution, pas une valeur en dur

L'exemple ESPHome envoie `roomnode: ${node_name}`. Cette substitution doit
être définie dans la configuration propre à la carte, par exemple :

```yaml
substitutions:
  node_name: roomnode-salon
```

Avantages :

- le **même extrait** sert à toutes les pièces, sans duplication ;
- la valeur envoyée correspond à la clé de `echo_by_roomnode` côté HA ;
- un nœud dont le nom n'est pas dans l'allowlist est **rejeté** par le
  script (aucune diffusion globale) : l'erreur de configuration devient
  visible dans les logs au lieu de parler dans la mauvaise pièce.

Le test statique `test_esphome_hook_is_documented_and_templated` vérifie que
la valeur reste une substitution, et non un identifiant figé.

## Limites connues — ne pas masquer

- Le composant ESPHome et le package sont **des exemples non encore testés de bout en bout** ; aucune carte n'a été flashée à ce stade.
- Les réponses Alexa utilisent **le cloud Amazon** et peuvent être retardées.
- Le succès de l'action `notify.send_message` ne signifie pas forcément que la lecture audio est achevée.
- Le réveil vocal à nouveau pendant qu'Alexa prononce sa réponse n'est pas empêché par ce package. Anti-bouclage et temporisation d'écoute sont **à développer et valider** au niveau ESPHome/Assist.
- Sans association explicite par `roomnode`, risque d'envoyer la réponse dans la mauvaise pièce ; ne **jamais** router automatiquement par 'dernier Alexa appelé'.
- Si Amazon ou Alexa Devices est indisponible, la commande Home Assistant peut déjà avoir été exécutée : l'échec de restitution ne doit pas annuler ou réexécuter l'action.

## Essais prévus

- [ ] Manuellement, `notify.send_message` parle sur le bon Echo.
- [ ] Le mapping refuse silencieusement les identifiants inconnus (aucune diffusion globale).
- [ ] Assist renvoie effectivement `on_tts_start` sans haut-parleur.
- [ ] Les réponses n'activent pas à répétition le microphone du RoomNode.
- [ ] Deux nœuds voisins ne produisent pas de double réponse.
- [ ] Test de 20 commandes avec mesure du délai médian et du taux de succès.

## Références

- https://esphome.io/components/voice_assistant/
- https://esphome.io/components/api/
- https://www.home-assistant.io/integrations/alexa_devices/
