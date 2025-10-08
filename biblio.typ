#import "@preview/fletcher:0.5.8": diagram, edge, node

= Étude bibliographique Ⅰ

#include "rapport/nix.typ"

== Gazebo & Unitree

=== Contexte

J'ai également été approchée pour travailler sur la création d'un _plugin_ pour Gazebo, un logiciel de simulation robotique @gazebo.

Le but était de pouvoir utiliser ce logiciel de simulation open source avec un robot de la companie Unitree, le H1v2 @h1v2, un robot humanoïde tout-usage.

=== Une base de code partiellement open-source

Une partie du code source de ce SDK n'est pas disponible, et n'est que distribué sous forme de binaires @sdk2-in-source-binaries. J'ai donc chercher à comprendre cette partie du code par ingénierie inverse, ce qui ne s'est pas avéré nécéssaire.

Au final, en explorant le code source du plugin pour un autre logiciel de simulation, Mujoco @mujoco @unitree-mujoco, j'ai pu comprendre comment interfacer le SDK avec Gazebo.

=== `rt/lowstate`, `rt/lowcmd`

Le SDK de Unitree fonctionne via des canaux DDS, une technologie de communication temps-réel bas niveau @dds.

Deux de ces canaux donnent accès au contrôle (resp. à l'état) bas-niveau des moteurs (resp. capteurs) du robot: `rt/lowcmd` (resp. `rt/lowstate`).

Grâce à l'étude des paquets transmis via Wireshark, j'ai pu débugger les communications entre mon plugin, _gz-unitree_, et le SDK.

Et au final, mon plugin fonctionne, en simulant un robot H1v2 via ces deux canaux:

#align(center, diagram(
  node((-1, 0))[Unitree SDKv2],
  edge("->", bend: 45deg)[`rt/lowcmd`],
  edge("<-", bend: -45deg)[`rt/lowstate`],
  node((0, 0))[gz-unitree],
  edge("<->")[`::PreUpdate`],
  node((1, 0))[Gazebo],
  edge("--"),
  node((2, 0))[Modèle SDF du robot],
))

=== Des tests end-to-end automatisés

Je souhaitais permettre de tester le code sur simulateur de manière automatique: on push un commit modifiant une politique de contrôle du robot, et, automatiquement, en CI, un test sous simulateur est lancé. On reçoit un artéfact avec une vidéo filmant le test.

Pour faire ceci, il a fallu rendre la fonctionnalité native à Gazebo d'enregistrement vidéo automatisable: elle ne l'est pas nativement, il a donc fallu que je duplique le code du module Gazebo correspondant, afin d'y rajouter de quoi contrôler l'entregistrement vidéo via des _topics_ Gazebo.

Il y a aussi un challenge lié au fait que, en CI, il n'y a pas d'interface graphique, ce qui rend le lancement de l'interface graphique de Gazebo impossible. Il faut donc simuler une interface graphique avec _XVFB_, un serveur X virtuel @xvfb.

=== Packaging sous Nix

Le packaging sous Nix de _gz-unitree_ est en cours, mais se heurte à quelques problèmes liés à l'état du packaging Nix de Gazebo lui-même: gazebo est packagé dans un _overlay_ tierce, _gazebo-sim-overlay_ @gazebo-sim-overlay, qui n'a pas mis à jour une des bibliothèques de Gaazebo depuis plus d'un an @gz-sim-overlay-update-msgs-issue
