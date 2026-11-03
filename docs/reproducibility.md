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
| SSID du point d'accès de secours | `RoomNode-Setup` — **identique pour tous les nœuds** : prévoir un changement si deux cartes sont utilisées simultanément |
| Clé de chiffrement API | peut être partagée ; preferable une clé par nœud (le nœud est alors ajouté individuellement dans HA) |
| Mot de passe OTA | peut être partagé |

> **Point d'attention :** le SSID du point d'accès de secours est figé dans
> `roomnode-43c-common.yaml` (`RoomNode-Setup`). Deux cartes branchées en même
> temps sur un même réseau émettent le même SSID. Pour lever l'ambiguïté,
> le rendre paramétrable (`ap_ssid`) dans une itération ultérieure, ou
> débrancher la seconde carte pendant le provisionnement de la première.
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
| Documentation BOM, câblage, alimentation, montage | **partiel** : `docs/gpio-43c.md` (câblage), `docs/hardware.md` (alimentation), `docs/sensors-43c.md` (radar). **BOM formel manquant** |
| Boîtier : ouverture micros, fenêtre écran, façade radar non métallique, ventilation SHT40 | **non fait** |
| Écriture installation / OTA / dépannage / sécurisation des secrets | **fait** pour ce qui est automatisable (§ 3, § 4, § 5) |
| Qualification de deux nœuds voisins | **non fait** (demande deux cartes) |
| Préparation d'une deuxième unité sans réécriture de code | **partiellement démontré** : le paramétrage par instance compile, mais le flash et la mise en service réels n'ont pas été faits |
