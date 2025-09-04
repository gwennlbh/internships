#import "@preview/arkheion:0.1.0": arkheion, arkheion-appendices
#import "@preview/fletcher:0.5.8": diagram, edge, node

#show: arkheion.with(
  title: "Étude bibliographique I",
  authors: (
    (name: "Gwenn Le Bihan", email: "gwenn.lebihan@etu.inp-n7.fr", affiliation: "ENSEEIHT"),
  ),
  date: "2 Septembre 2025",
  abstract: [
    Ce stage porte sur l'intégration de Nix et NixOS dans les processus de développement et de déploiement logiciel dans le domaine robotique au sein du LAAS. Nix, le _package manager_, et NixOS, l'OS, sont des technologies permettant une reproductibilité, une qualité importante dans le monde de la recherche.

    J'ai été aussi amenée à travailler sur la création d'un _plugin_ pour Gazebo, un logiciel de simulation robotique, pour l'utiliser avec le _SDK_ d'un robot de Unitree.
  ],
)

#outline(
  title: [Table des matières],
)

= Reproductibilité

== État dans le domaine de la programmation

La différence entre une fonction au sens mathématique et une fonction au sens programmatique consiste en le fait que, par des raisons de practicité, on permet aux `function`s des langages de programmation d'avoir des _effets de bords_. Ces effets affectent, modifient ou font dépendre la fonction d'un environnement global qui n'est pas explicitement déclaré comme une entrée (un argument) de la fonction en question @purefunctions.

Cette liberté permet, par exemple, d'avoir accès à la date et à l'heure courante, interagir avec un système de fichier d'un ordinateur, générer une surface pseudo aléatoire par bruit de Perlin, etc.

Mais, en contrepartie, on perd une équation qui est fondamentale en mathématiques:

$
  forall E, F, forall f: E->F, forall (e_1, e_2) in E^2, e_1 = e_2 => f(e_1) = f(e_2)
$

En programmation, on peut très facilement construire un $f$ qui ne vérifie pas ceci:

```python
from datetime import date

def f(a):
  return date.today().year + a
```

Selon l'année dans laquelle nous sommes, $mono(f)(0)$ n'a pas la même valeur.

De manière donc très concrète, si cette fonction `f` fait partie du protocole expérimental d'une expérience, cette expérience n'est plus reproductible, et ses résultats sont donc potentiellement non vérifiables, si le papier est soumis le 15 décembre 2025 et la _peer review_ effectuée le 2 janvier 2026.

== Contenir les effets de bords

En dehors du besoin de vérifiabilité du monde de la recherche, la reproductibilité est une qualité recherchée dans certains domaines de programmation @reproducibility

Il existe donc depuis longtemps des langages de programmation dits _fonctionnels_, qui, de manière plus ou moins stricte, limite les effets de bords. Certains langages font également la distinction entre une fonction _pure_#footnote[sans effets de bord] et une fonction classique @fortran-pure. Certaines fonctions, plutôt appelées _procédures_, sont uniquement composées d'effet de bord puisqu'elle ne renvoie pas de valeur @ibm-function-procedure-routine


== État dans le domaine de la robotique

En robotique, pour donner des ordres au matériel, on intéragit beaucoup avec le monde extérieur (ordres et lecture d'état de servo-moteurs, flux vidéo d'une caméra, etc), souvent dans un langage plutôt bas-niveau, pour des questions de performance et de proximité abstractionnelle au matériel

De fait, les langages employés sont communément C, C++ ou Python#footnote[Il arrive assez communément d'utiliser Python, un langage haut-niveau, mais c'est dans ce cas   à but de prototypage, et le code contrôlant les moteurs est écrit dans un langage bas niveau plus appelé par Python par FFI] @programming-languages-robotics, des langages bien plus impératifs que fonctionnels @imperative-languages.

L'idée de s'affranchir d'effets de bords pour rendre les programmes dans la recherche en robotique reproductibles est donc plus utopique que réaliste.


== Environnements de développement

Cependant, ce qui fait un programme n'est pas seulement son code: surtout dans des langages plus anciens sans gestion de dépendance simple, les dépendances (bibliothèques) du programme, ainsi que l'environnement et les étapes de compilation de ce dernier, représentent également une partie considérable de la complexité du programme (par exemple, en C++, on utilise un outil générant des fichiers de configuration pour un autre outil qui à son tour configure le compilateur de C++ @cmake)

C'est cette partie que Nix, le gestionnaire de paquet, permet d'encapsuler et de rendre reproductible. Dans ce modèle, la compilation (et de manière plus générale la construction, ou _build_) du projet est la fonction que l'on veut rendre pure. L'entrée est le code source, et le résultat de la fonction est un binaire, qui ne doit dépendre que du code source.

$
  forall "src", "bin", forall f in "bin"^"src", forall (P_1, P_2) in "src"^2, P_1 = P_2 => f(P_1) = f(P_2)
$

Ici, $P_1$ et $P_2$ sont deux itérations du code source (src) du programme. Si le code source est identique, les binaires résultants de la compilation ($f$) sont égaux, au sens de l'égalité bit à bit.

On a la proposition (1), avec $E = "src"$, l'ensemble des code source possibles pour un langage, et $F= "bin"$, l'ensemble des binaires éxécutables

Nix ne peut pas garantir que le programme sera sans effets de bords au _runtime_, mais vise à le garantir au _build-time_.

= Nix, le gestionnaire de paquets pur

== Un _DSL_#footnote[Domain-Specific Language] fonctionnel

Une autre caractéristique que l'on trouve souvent dans la famille de langages fonctionnels est l'omniprésence des _expressions_: quasi toute les constructions syntaxiques forment des expressions valides, et peuvent donc servir de valeur

#table(
  columns: (50%, 50%),
  ```python
  def g(x, y):
    if y == 5:
      x = 6
    else:
      x = 8
    return f(x)
  ```,
  ```ocaml
  let g x y = f (
    if y = 5 then
      6
    else
      8
  )
  ```,

  [ *Python* (`if` et `else` sont des instructions) ], [ *OCaml* (`if` et `else` forment une expression) ],
)

Afin de décrire les dépendances d'un programme, l'environnement de compilation, et les étapes pour le compiler (en somme, afin de définir le $f in "bin"^"src"$), Nix comprend un langage d'expressions @nix-language. Un fichier `.nix` définit une fonction, que Nix sait exécuter pour compiler le code source.

#table(
  columns: (50%, 50%),
  table.header([Expression d'une fonction en Python], [En Nix]),
  ```python
  lambda f(a): a + 3
  ```,
  ```nix
  { a }: a + 3
  ```,
)

Voici un exemple de définition d'un programme, appelée _dérivation_ dans le jargon de Nix:


```nix
{
  src-odri-masterboard-sdk,

  lib,
  stdenv,
  jrl-cmakemodules,
  cmake,
  python3Packages,
  catch2_3,
}:

stdenv.mkDerivation {
  pname = "odri_master_board_sdk";
  version = "1.0.7";

  src = src-odri-masterboard-sdk;

  preConfigure = ''
    cd sdk/master_board_sdk
  '';

  doCheck = true;

  cmakeFlags = [
    (lib.cmakeBool "BUILD_PYTHON_INTERFACE" stdenv.hostPlatform.isLinux)
  ];

  nativeBuildInputs = [
    jrl-cmakemodules
    python3Packages.python
    cmake
  ];

  buildInputs = with python3Packages; [ numpy ];

  nativeCheckInputs = [ catch2_3 ];

  propagatedBuildInputs = with python3Packages; [ boost ];
}
```

La dérivation ici prend en entrée le code source (`src-odri-masterboard-sdk`), ainsi que des dépendances, que ce soit des fonctions relatives à Nix même (comme `stdenv.mkDerivation`) pour simplifier la définition de dérivation, ou des dépendances au programmes, que ce soit pour sa compilation ou pour son exécution (dans ce dernier cas de figures, les dépendances sont inclues ou reliées au binaire final)

== Un ecosystème de dépendances

Afin de conserver la reproductibilité même lorsque l'on dépend de libraries tierces, ces dépendances doivent également avoir une compilation reproductible: on déclare donc des dépendances à des _packages_ Nix, disponibles sur _Nixpkgs_ @nixpkgs.

Parfois donc, écrire un paquet Nix pour son logiciel demande aussi d'écrire les paquets Nix pour les dépendances de notre projet, si celles-ci n'existent pas encore, et cela récursivement. On peut ensuite soumettre nos paquets afin que d'autres puissent en dépendre sans les réécrire, en contribuant à _Nixpkgs_ @nixpkgs-contributing

Pour ne pas avoir à compiler toutes les dépendances soit-même quand on dépend de `.nix` de _nixpkgs_, il existe un serveur de cache, qui propose des binaires des dépendances, Cachix @cachix

== Une compilation dans un environnement fixé

Certains aspects de l'environnement dans lequel l'on compile un programme peuvent faire varier le résultat final. Pour éviter cela, Nix limite au maximum les variations d'environnement. Par exemple, la date du système est fixée au 0 UNIX (1er janvier 1990): le programme compilé ne peut pas dépendre de la date à laquelle il a été compilé.

Quand le _sandboxing_ est activé, Nix isole également le code source de tout accès au réseau, aux autres fichiers du système (ainsi que d'autres mesures) pour améliorer la reproductibilité @nix-sandboxing

=== Un complément utile: compiler en CI

Pour aller plus loin, on peut lancer la compilation du paquet Nix en _CI_#footnote[Continuous Integration, lit. intégration continue], c'est-à-dire sur un serveur distant au lieu de sur sa propre machine. On s'assure donc que l'état de notre machine de développement personnelle n'influe pas sur la compilation, puisque chaque compilation est lancée dans une machine virtuelle vierge @github-runners.

= NixOS, un système d'exploitation à configuration déclarative

Une fois le programme compilé avec ses dépendances, il est prêt à être transféré sur l'ordinateur ou la carte de contrôle embarquée au robot.

Lorsqu'il y a un ordinateur embarqué, comme par exemple une Raspberry Pi @raspi, il faut choisir un OS sur lequel faire tourner le programme.

La encore, un OS s'accompagne d'un amas considérable de configuration des différentes parties du système: accès au réseau, drivers,…

Sur les OS Linux classiques tels que Ubuntu ou Debian, cette configuration est parfois stockée dans des fichiers, ou parfois retenue en mémoire, modifiée par l'execution de commandes.

C'est un problème assez récurrent dans Linux de manière générale: d'un coup, le son ne marche plus, on passe ½h sur un forum à copier-coller des commandes dans un terminal, et le problème est réglé… jusqu'à ce qu'il survienne à nouveau après un redémarrage ou une réinstallation.

Ici, NixOS assure que toute modification de la configuration d'un système est _déclarée_ (d'où l'adjectif "déclaratif") dans des fichiers de configurations, également écrit dans des fichiers `.nix` @nixos-impatient.

Ici encore, cela apporte un gain en terme de reproductibilité: l'état de configuration de l'OS sur lequel est déployé le programme du robot est, lui aussi, rendu reproductible.

= Gazebo & Unitree

== Contexte

J'ai également été approchée pour travailler sur la création d'un _plugin_ pour Gazebo, un logiciel de simulation robotique @gazebo.

Le but était de pouvoir utiliser ce logiciel de simulation open source avec un robot de la companie Unitree, le H1v2 @h1v2, un robot humanoïde tout-usage.

== Une base de code partiellement open-source

Une partie du code source de ce SDK n'est pas disponible, et n'est que distribué sous forme de binaires @sdk2-in-source-binaries. J'ai donc chercher à comprendre cette partie du code par ingénierie inverse, ce qui ne s'est pas avéré nécéssaire.

Au final, en explorant le code source du plugin pour un autre logiciel de simulation, Mujoco @mujoco @unitree-mujoco, j'ai pu comprendre comment interfacer le SDK avec Gazebo.

== `rt/lowstate`, `rt/lowcmd`

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
  node((2, 0))[Modèle SDF du robot]
))

== Des tests end-to-end automatisés

Je souhaitais permettre de tester le code sur simulateur de manière automatique: on push un commit modifiant une politique de contrôle du robot, et, automatiquement, en CI, un test sous simulateur est lancé. On reçoit un artéfact avec une vidéo filmant le test.

Pour faire ceci, il a fallu rendre la fonctionnalité native à Gazebo d'enregistrement vidéo automatisable: elle ne l'est pas nativement, il a donc fallu que je duplique le code du module Gazebo correspondant, afin d'y rajouter de quoi contrôler l'entregistrement vidéo via des _topics_ Gazebo.

Il y a aussi un challenge lié au fait que, en CI, il n'y a pas d'interface graphique, ce qui rend le lancement de l'interface graphique de Gazebo impossible. Il faut donc simuler une interface graphique avec _XVFB_, un serveur X virtuel @xvfb.

== Packaging sous Nix

Le packaging sous Nix de _gz-unitree_ est en cours, mais se heurte à quelques problèmes liés à l'état du packaging Nix de Gazebo lui-même: gazebo est packagé dans un _overlay_ tierce, _gazebo-sim-overlay_ @gazebo-sim-overlay, qui n'a pas mis à jour une des bibliothèques de Gaazebo depuis plus d'un an @gz-sim-overlay-update-msgs-issue



#bibliography("bib.yaml")
