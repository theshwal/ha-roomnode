# Reproductibilité, installation et dépannage (issue #5)

Objectif de l'issue : « une deuxième unité peut être préparée à partir de la
documentation sans réécriture de code ».

> Aucun essai physique. Les Procedures ci-dessous sont **écrites et vérifiées
> pour ce qui est automatisable** (validation de configuration et compilation
> réelles), mais le montage, la mise en service et le dépannage sur carte
> n'ont pas été exécutés.

## 1. Configuration par instance

Le principe : **un seul firmware**, paramétré par pièce. Aucun fork, aucune
duplication de code.

| Ce qui change par pièce | Où | Variable |
| --- | --- | --- |
| Nom de nœud ESPHome (mDNS) | `firmware/instance-<piece>.yaml` | `node_name` |
| Nom lisible dans HA | idem | `node_friendly_name` |
| Zone Home Assistant | idem | `ha_zone` |
| Libellé de pièce (écran, logs) | idem | `room_label` |
| Entité Speak de l'Echo associé | idem | `echo_speak_entity` |
| Entité cible de l'Echo | idem | `echo_target_entity` |

Les **secrets** (Wi-Fi, OTA, clé API) restent dans le fichier de secrets
local, jamais versionné. Un fichier de secrets peut être partagé entre
pièces si le réseau est le même ; sinon un fichier par pièce.

### Fichiers

| Fichier | Rôle |
| --- | --- |
| `firmware/roomnode-43c-common.yaml` | socle (plateforme, Wi-Fi, API, OTA, PSRAM) — paramétré par substitutions |
| `firmware/roomnode-43c.yaml` | cible V1 (écran RGB, tactile, micro, Assist) — commun à toutes les pièces |
| `firmware/instance-example.yaml` | **modèle** des paramètres d'instance |
| `firmware/roomnode-43c-instance.yaml` | **profil d'exemple** d'une instance |

### Préparer une nouvelle pièce

1. Copier `firmware/instance-example.yaml` → `firmware/instance-<piece>.yaml`
   et renseigner les substitutions (`node_name` en minuscules, sans espace,
   unique sur le réseau).
2. Copier `firmware/roomnode-43c-instance.yaml` →
   `firmware/roomnode-43c-<piece>.yaml` et changer l'include `params`.
3. Créer le fichier de secrets local (voir § 3).
4. Valider : `scripts/validate.sh` (schéma) puis compiler.
5. Flasher : `esphome run firmware/roomnode-43c-<piece>.yaml`.

### Vérification du paramétrage

La validation ESPHome confirme que les substitutions sont bien appliquées :

```bash
esphome config firmware/roomnode-43c-instance.yaml | grep -A3 substitutions
```

```
substitutions:
  node_name: roomnode-salon
  name: roomnode-salon
  friendly_name: RoomNode Salon
```

Preuve par la compilation : le binaire produit s'appelle
`roomnode-salon.bin` (et non `roomnode.bin`).

## 2. Nomenclature et coexistence de deux nœuds voisins

| Élément | Règle |
| --- | --- |
| `node_name` | `roomnode-<piece>`, minuscules, unique sur le réseau local |
| mDNS | `roomnode-<piece>.local` |
| SSID du point d'accès de secours | **dérivé de `node_name`** : `<node_name>-Setup` (ex. `roomnode-salon-Setup`). Deux nœuds voisins sont donc distinguables au provisionnement |
| Clé de chiffrement API | peut être partagée ; preferable une clé par nœud (le nœud est alors ajouté individuellement dans HA) |
| Mot de passe OTA | peut être partagé |

> **Point résolu :** le SSID du point d'accès de secours n'est plus figé.
> Il dérive de la substitution `node_name`
> (`ssid: "${node_name}-Setup"` dans `roomnode-43c-common.yaml`), donc
> `roomnode-salon-Setup` pour une pièce donnée. Deux cartes voisines
> émettent des SSID distincts et restent distinguables au provisionnement.
> Le mot de passe du point d'accès reste un secret local, propre à chaque
> installation.
>
> La clé de chiffrement API est, elle, propre au fichier de secrets : une
> clé par nœud est la bonne pratique.

La « qualification de la coexistence de deux nœuds voisins » (issue #5) n'est
**pas** faite : elle demande deux cartes réelles.

## 3. Secrets et sécurité

| Fichier | Versionné ? | Contenu |
| --- | --- | --- |
| `secrets.example.yaml` | oui | **modèle**, valeurs factices |
| fichier de secrets local | **non** (`.gitignore`) | Wi-Fi, mot de passe OTA, clé API |

```bash
cp secrets.example.yaml <fichier-de-secrets-local>.yaml
$EDITOR <fichier-de-secrets-local>.yaml
```

Clé API : `esphome encrypt "une-phrase-de-32-octets-minimum-ici"`.

Règles :

- le fichier de secrets local n'est **jamais** lu par `scripts/validate.sh`
  (il substitue des valeurs factices dans une copie temporaire) ;
- il ne doit jamais être commité ni collé dans une issue ou une PR ;
- l'adresse IP du nœud n'est pas versionnée : elle est lue à l'exécution par
  `network::get_ip_addresses()` et affichée sur l'écran de diagnostics.

## 4. Installation et flash

Prérequis, procédure de flash et plan de test : [flash-43c.md](flash-43c.md).

En résumé :

```bash
esphome run firmware/roomnode-43c-<piece>.yaml
esphome logs firmware/roomnode-43c-<piece>.yaml
```

Mise à jour OTA ensuite :

```bash
esphome run firmware/roomnode-43c-<piece>.yaml --device roomnode-<piece>.local
```

## 5. Dépannage

| Symptôme | Cause probable | Vérification |
| --- | --- | --- |
| Le nœud n'apparaît pas dans HA | clé API différente de celle déclarée dans HA, ou nœud non ajouté | `esphome logs` : la session API doit s'ouvrir |
| `Failed config` à la validation | substitution absente ou nom d'instance erroné | `esphome config <profil>` : le message nomme la substitution fautive |
| Écran noir | alimentation insuffisante (l'écran consomme ~550 mA) | vérifier la source 5 V et le sélecteur `PWR` |
| Écran noir, SPI correct | la séquence d'init GC9107/ST7701S peut ne pas correspondre à la révision | vérifier la révision de l'écran |
| Aucun capteur I²C | le bus I²C est unique et partagé (6 périphériques) | `esphome logs` : `I2C bus scan` doit lister `0x5D`, `0x40`, `0x44`… |
| Tactile inactif | reset GT911 non appliqué, ou IRQ non câblé | vérifier `CTP_RST` (CH422G pin 1) et `CTP_IRQ` (GPIO4) |
| Micro muet | ES7210 non initialisé, ou `mic_gain` trop bas / TDM | `esphome logs` : `ES7210 audio ADC` au démarrage |
| Le radar ne répond pas | UART à 256000 bauds, ou **alimentation 5 V manquante** | vérifier le rail 5 V et le câblage GPIO15/GPIO12 |
| Flash échoue | mode bootloader : maintenir BOOT puis brancher USB | `[device]` : `/dev/ttyACM0` doit apparaître |
| Compilation échoue après un ajout | API ESPHome différente de celle testée ici | compiler avec `esphome==2026.10.1` |

## 6. Preuves de compilation

Commande :

```bash
ESPHOME_COMPILE=1 scripts/validate.sh
```

Résultat : **exit code 0**.

| Profil | Binaire | Taille image | RAM (DIRAM) | Flash (part. app) |
| --- | --- | ---: | ---: | ---: |
| `43c` | `roomnode.bin` | 919 307 o | 110 235 o (32,3 %) | 11,3 % |
| `43c-instance` | `roomnode-salon.bin` | 919 311 o | 110 267 o (32,3 %) | 11,3 % |

L'écart de 4 octets vient du nom plus long. La substitution du nom de nœud
est donc bien propagate jusqu'au binaire.

Extrait de journal :
[`docs/build-43c-instance-output.txt`](build-43c-instance-output.txt).

## 7. Ce qui reste à faire pour l'issue #5

| Point | État |
| --- | --- |
| Séparation configuration commune / paramètres par nœud | **fait** (substitutions + fichier d'instance) |
| Documentation BOM, câblage, alimentation, montage | **fait pour la nomenclature et les contraintes** : [`docs/bom-43c.md`](bom-43c.md) (carte, capteurs, câblage, alimentation, limites de boîtier, sources) + `docs/gpio-43c.md`, `docs/sensors-43c.md`. **BOM chiffrée (prix) et photos : non faits** |
| Boîtier : ouverture micros, fenêtre écran, façade radar non métallique, ventilation SHT40 | **non fait** |
| Écriture installation / OTA / dépannage / sécurisation des secrets | **fait** pour ce qui est automatisable (§ 3, § 4, § 5) |
| Qualification de deux nœuds voisins | **non fait** (demande deux cartes) |
| Préparation d'une deuxième unité sans réécriture de code | **partiellement démontré** : le paramétrage par instance compile, mais le flash et la mise en service réels n'ont pas été faits |

## 8. Audit d'intégration : extract Assist → Alexa (PR #6)

La PR #6 fournit un extrait à fusionner sous le bloc `voice_assistant:` :

```yaml
voice_assistant:
  id: roomnode_assist
  microphone: roomnode_microphone
  on_tts_start:
    - homeassistant.action:
        action: script.roomnode_speak
        ...
```

**Audit de compatibilité avec le profil V1 actuel** (4.3C), réalisé en
configuration seule, **sans déploiement ni essai matériel** :

| Point | Résultat |
| --- | --- |
| `on_tts_start` existe dans `voice_assistant` | **oui** — `CONF_ON_TTS_START` est supporté par le composant ESPHome 2026.10.1 |
| Le bloc `voice_assistant:` du profil V1 accepte `on_tts_start` | **oui** — le bloc inséré sur le profil V1 passe `esphome config` (`INFO Configuration is valid!`) |
| Action `homeassistant.action` avec `data_template` / `variables` | **oui** — schéma accepté |
| Identifiants | à aligner : l'extrait utilise `id: roomnode_assist` et `roomnode_microphone`, le profil V1 utilise `id: va` et `mic_es7210` |
| Chaîne Home Assistant → Alexa Devices | **non testée** — la PR #6 reste draft |

### Déclenchement : une fois par réponse

Vérifié dans le code du composant ESPHome 2026.10.1
(`voice_assistant.cpp`, cas `VOICE_ASSISTANT_TTS_START`) :

- le déclencheur est appelé **une seule fois par réponse TTS**, avec le texte
  complet dans la variable `x` ;
- un événement TTS **sans texte** est ignoré (rien n'est envoyé à l'Echo) ;
- un texte de plus de **500 caractères** est tronqué par ESPHome à 497
  caractères + « ... ».

La borne de 500 caractères du script HA (`0 < length <= 500`) est donc
**cohérente** avec le comportement d'ESPHome : un texte tronqué par le
composant passe encore le filtre, un texte vide est rejeté des deux côtés.

### Double déclenchement

Le risque est réel et **couvert par des tests statiques dans la PR #6**
(`tests/test_alexa_bridge.py`) :

| Cas | Garantie |
| --- | --- |
| Nœud non enregistré dans l'allowlist | **rejeté** — `target_speak` est vide, la condition échoue, aucune diffusion globale |
| Cible qui n'est pas une entité `notify.*_speak` | **rejeté** (ex. `notify.all`) |
| Message vide ou > 500 caractères | **rejeté** |
| Deux nœuds voisins | **garantie structurelle** : le routage est par `roomnode`, donc un Echo par nœud. Mais deux nœuds **distincts** ne partagent pas la même clé `roomnode` — le test « deux nœuds voisins ne produisent pas de double réponse » reste **à faire sur matériel** |

Le risque de double énoncé **par un seul nœud** (réactivation de l'écoute
pendant que l'Echo parle) est explicitement **hors périmètre du package** :
la doc de #6 le signale et renvoie au développement d'un anti-bouclage au
niveau ESPHome/Assist. C'est un point ouvert, pas une solution.

### Cas d'erreur

| Cas | Traitement |
| --- | --- |
| `homeassistant.action` refusée par HA (device non autorisé) | l'action ESPHome `homeassistant.action` lève une erreur → le `on_error` de l'extrait #6 journalise « impossible de demander la réponse vocale à Home Assistant » |
| Amazon / Alexa Devices indisponible | `notify.send_message` échoue **après** que la commande HA a pu s'exécuter. La doc de #6 impose que cet échec **n'annule ni ne rejoue** l'action. Le script est en `mode: queued`, `max: 10` : une saturation de la file est un point de vigilance |
| Message non prononçable ( Echo absent ) | aucune relance automatique n'est implémentée |

### Sécurité — ce qui est vérifié

| Mesure | État |
| --- | --- |
| Routage par allowlist `roomnode → notify.*_speak`, jamais « dernier Echo appelé » | **vérifié** par test statique |
| Refus des cibles non-`notify.*_speak` | **vérifié** par test statique |
| Bornes de taille de message | **vérifiées** par test statique |
| Aucun secret, IP, identifiant Amazon ou nom d'appareil réel dans le dépôt | **vérifié** : le mapping d'exemple est `roomnode_test: notify.replace_with_your_echo_speak` |
| Autorisation HA requise | documentée : « Allow the device to perform Home Assistant actions » |

### Écart concret à corriger : l'identifiant de nœud est figé

L'extrait de #6 envoie `roomnode: roomnode_test` en dur. Or la configuration
par instance de ce dépôt expose déjà une substitution `node_name`
(`firmware/roomnode-43c-common.yaml`). Pour que la PR #6 soit réutilisable
pièce par pièce, le hook doit envoyer `${node_name}` :

```yaml
  on_tts_start:
    - homeassistant.action:
        action: script.roomnode_speak
        data:
          roomnode: ${node_name}
```

C'est **la seule correction nécessaire** du côté ESPHome pour rendre
l'extract #6 compatible avec la paramétrisation par pièce. Elle n'est pas
appliquée ici : la PR #6 est lapropriété de l'extrait, et l'appliquer
supprimerait la valeur d'exemple lisible qui sert de référence au lecteur.

**Cette correction est validée** : l'extrait modifié (`roomnode:
${node_name}`, bloc `on_tts_start` avec `on_error`) passe `esphome config`
puis `esphome compile` sur le profil V1 4.3C.

```
roomnode.bin binary size 0xe11a0 bytes. Smallest app partition is 0x7c0000 bytes. 0x6dee60 bytes (89%) free.
RAM:   [===       ]  32.3% (used 110339 bytes from 341760 bytes)
Flash: [=         ]  11.3% (used 921907 bytes from 8126464 bytes)
INFO Successfully compiled program.
```

Extrait de journal :
[`docs/audit-alexa-integration-output.txt`](audit-alexa-integration-output.txt).

Deux autres écarts restent à aligner lors de l'intégration : les
**identifiants** (`id: roomnode_assist` / `roomnode_microphone` contre
`id: va` / `mic_es7210`) et le fait que l'extrait suppose un profil à
micro simple alors que le profil V1 déclare une **liste** de sources micro
(`microphone: [{microphone: mic_es7210, channels: [0]}]`).

L'audit ne porte que sur la **validité de la configuration** et sur le
comportement *documenté* du composant. Il ne dit rien du comportement de la
chaîne vocale, qui reste non testé de bout en bout.
