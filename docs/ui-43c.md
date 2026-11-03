# Interface tactile LVGL de pièce — 4,3″ 800×480 (issue #4)

Cible : Waveshare **ESP32-S3-Touch-LCD-4.3C**, profil `roomnode-43c-ui.yaml`.

> Aucun essai physique. Ce document décrit une interface **compilée et
> validée statiquement**, jamais observée sur la carte.

## Contenu de l'interface

Deux pages, sans GPIO supplémentaire (l'interface réutilise l'écran RGB et le
tactile GT911 du profil V1).

### Page 1 — « Pièce »

| Zone | Contenu | Source de l'état |
| --- | --- | --- |
| Bandeau | état micro/Assist + heure | `voice_assistant` + horloge |
| Mesures | température, humidité, présence | variables globales (capteurs, #3) |
| Commandes | Lumière / Volet / Chauffage | `switch` ESPHome pilotés par HA |
| Pied | lien vers Diagnostics | navigation LVGL |

### Page 2 — « Diagnostics »

| Zone | Contenu | Source de l'état |
| --- | --- | --- |
| Statuts | Wi-Fi, Home Assistant, micro, PSRAM, adresse IP | variables globales |
| Action | coupure du micro (mute) | `switch` + `microphone.mute` |
| Pied | retour à la page Pièce | navigation LVGL |

## Déterminisme

C'est une exigence explicite de l'issue #4 : « n'utiliser que des contrôles
déterministes, l'agent vocal restant optionnel ».

- Les trois commandes (lumière / volet / chauffage) sont des **`switch`
  ESPHome**. Le tactile déclenche `switch.toggle`, qui produit une commande
  Home Assistant standard. **Aucune n'appelle l'agent vocal**, aucun scenario
  n'est requis côté HA pour que le bouton fonctionne.
- L'interface **ne déclenche jamais la voix** : elle ne fait que lire l'état
  du composant `voice_assistant` et l'afficher.
- Les libellés sont recalculés à partir de **variables globales ESPHome**, pas
  d'appels HTTP depuis l'écran : pas de dépendance réseau à l'affichage.
- Le cycle de rafraîchissement est un `interval` de 2 s, **indépendant du
  passage de la voix**.

## Mute micro

Le bouton « Micro » de la page Diagnostics actionne `microphone.mute` /
`microphone.unmute` sur le microphone ES7210. Cela coupe **l'écoute** sans
interrompre la session de capture ni le pipeline STT déjà en cours.

À noter : l'ES8311 (DAC) et le NS4150 ne sont pas activés en V1 — il n'y a
donc **pas de sortie audio locale** à couper. Le mute ne concerne que le
micro.

## Budget mémoire

| Profil | Image | RAM (DIRAM) | Flash (part. app) |
| --- | ---: | ---: | ---: |
| `43c` (V1 sans UI) | 919 307 o | 110 235 o (32,3 %) | 11,3 % |
| `43c-ui` (V1 + LVGL) | 1 152 347 o | 112 347 o (32,9 %) | 14,2 % |

L'interface LVGL coûte **+233 040 o de flash** et **+2 112 o de RAM
interne**. Le coût RAMprincipal est dans le **tampon d'affichage** (RGB
800×480), alloué en PSRAM par le modèle `mipi_rgb` : `buffer_size: 25 %` est
demandé à LVGL.

> Le budget « fluidité avec micro / wake word actifs » demandé par l'issue
> **n'a pas été mesuré** : cela exige la carte. Ce qui est vérifié ici, c'est
> que la compilation tient dans la partition de 8 Mo (86 % libres) et que la
> RAM interne reste à 32,9 %.

## Points techniques à connaître pour la suite

1. **`lvgl.label.update`** est l'action qui met à jour le **texte** d'un
   label. `lvgl.widget.update` ne gère que les propriétés de style : le
   champ `text` y est refusé (« `[text]` is an invalid option »).
2. **Les lambdas multi-lignes ne sont pas acceptés** dans `args:` d'une
   action LVGL : le générateur produit une erreur « expected
   primary-expression ». Le texte doit venir d'une expression simple
   (typiquement une variable globale).
3. **API Wi-Fi portable** : `wi_sta_ip_address()` n'existe pas sous
   esp-idf. L'IP se lit via `network::get_ip_addresses()` puis
   `IPAddress::str_to(char*)`. Le niveau de signal en dBm n'est pas exposé de
   façon portable sous esp-idf : l'interface affiche donc un **état de
   connexion** plutôt qu'un dBm.
4. **Fusion de `voice_assistant`** : le bloc `voice_assistant:` de l'UI
   (mêmes `id: va`) se **fusionne** avec celui du profil V1. Les automation
   `on_client_connected`, `on_listening`, `on_end`, `on_error` peuvent donc
   être déclarées dans l'un ou l'autre — sans duplication à écrire dans le
   profil V1.

## Limites — **aucun test physique n'a été réalisé**

L'interface compile et sa configuration est valide, mais rien n'a été vu :

1. Le rendu 800×480 est-il correct ? (orientation, marges,_density)
2. Les cinq points du tactile GT911 correspondent-ils aux coordonnées
   affichées ? (la calibration n'est pas faite)
3. Les boutons tactile déclenchent-ils bien les `switch` côté HA ?
4. L'indicateur « Voix » suit-il les états réels (`ecoute`, `pret`,
   `hors ligne`, `erreur`) ?
5. L'heure affichée est-elle correcte ? (RTC PCF85063 ou SNTP non encore
   configurés : l'heure n'est pas câblée dans ce profil)
6. Le mute coupe-t-il bien l'entrée micro sans casser le pipeline ?
7. La fluidité est-elle acceptable quand l'écran 800×480 et l'audio sont
   actifs en même temps ?
8. L'interface reste-elle lisible en plein jour et en mode nuit ?
   (l'adaptation jour/nuit demandée par l'issue n'est **pas** implémentée :
   les couleurs sont fixes)

### Écrans non couverts

L'issue #4 demande aussi : « affichage adapté jour/nuit », « réveil par
toucher ou présence », « équipements principaux et scénarios de la zone ».
Ces points **ne sont pas traités** dans cette première étape : le rapport
est volontairement limité à une interface de base vérifiable par compilation,
sans revendiquer la couverture complète de l'issue.
