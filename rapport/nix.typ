== Reproductibilité

=== État dans le domaine de la programmation

La différence entre une fonction au sens mathématique et une fonction au sens programmatique consiste dans le fait que, pour des raisons de practicité, on permet aux `function`s des langages de programmation d'avoir des _effets de bords_. Ces effets affectent, modifient ou font dépendre la fonction d'un environnement global qui n'est pas explicitement déclaré comme une entrée (argument) de la fonction en question @purefunctions.

Cette liberté permet, par exemple, d'avoir accès à la date et à l'heure courante, d'interagir avec un système de fichier d'un ordinateur, de générer une surface pseudo aléatoire par bruit de Perlin, etc.

Mais, en contrepartie, on perd une équation qui est fondamentale en mathématique:

$
  forall E, F, forall f: E->F, forall (e_1, e_2) in E^2, e_1 = e_2 => f(e_1) = f(e_2)
$

En programmation, on peut très facilement construire un $f$ qui ne vérifie pas ceci:

```python
from datetime import date

def f(a):
  return date.today().year + a
```

Selon l'année dans laquelle nous sommes, `f(0)` n'a pas la même valeur.

De manière donc très concrète, si cette fonction `f` fait partie d'un protocole expérimental, l'expérience n'est plus reproductible, et ses résultats sont donc potentiellement non vérifiables, si le papier est soumis le 15 décembre 2025 et la _peer review_ effectuée le 2 janvier 2026.

=== Contenir les effets de bords

En dehors du besoin de vérifiabilité du monde de la recherche, la reproductibilité est une qualité recherchée en programmation @reproducibility.

Il existe donc des langages de programmation dits _fonctionnels_, qui, de manière plus ou moins stricte, limitent les effets de bords. Certains langages font également la distinction entre une fonction _pure_ (sans effets de bord) et une fonction classique @fortran-pure. Certaines fonctions, plutôt appelées _procédures_, sont uniquement composées d'effet de bord et ne renvoient pas de valeur @ibm-function-procedure-routine.


=== État dans le domaine de la robotique

En robotique, pour donner des ordres au matériel, on interagit beaucoup avec le monde extérieur (ordres et lecture d'état de servo-moteurs, flux vidéo d'une caméra, etc.), souvent dans un langage plutôt bas-niveau, pour des questions de performance et de proximité abstractionnelle au matériel.

De fait, les langages employés sont communément C, C++ ou Python#footnote[Il arrive assez communément d'utiliser Python, un langage haut-niveau, mais c'est dans ce cas   à but de prototypage. Le code contrôlant les moteurs est écrit dans un langage bas niveau, mais appelé par Python via FFI.] @programming-languages-robotics, des langages bien plus impératifs que fonctionnels @imperative-languages.

L'idée de s'affranchir d'effets de bords pour rendre les programmes dans la recherche en robotique reproductibles est donc plus utopique que réaliste.


=== Reproductibilité de la compilation

Cependant, ce qui fait un programme n'est pas seulement son code: surtout dans des langages plus anciens sans gestion de dépendance intégrée au langage, les dépendances (bibliothèques) du programme, ainsi que l'environnement et les étapes de compilation de ce dernier, représentent également une partie considérable de la complexité du programme (par exemple, en C++, on utilise un outil générant des fichiers de configuration pour un autre outil qui à son tour configure le compilateur de C++#footnote[Il est ici question de CMake, qui génère des Makefile configurant GCC] @cmake)

C'est cette partie que Nix, le gestionnaire de paquet, permet d'encapsuler et de rendre reproductible. Dans ce modèle, la compilation (et de manière plus générale la construction, ou _build_) du projet est la fonction que l'on veut rendre pure. L'entrée est le code source, et le résultat de la fonction est un binaire, qui ne doit dépendre que du code source.

$
  forall "src", "bin", forall f in "bin"^"src", forall (P_1, P_2) in "src"^2, P_1 = P_2 => f(P_1) = f(P_2)
$

Ici, $P_1$ et $P_2$ sont deux itérations du code source (éléments de src) du programme. Si le code source est identique, les binaires résultants de la compilation ($f$) sont égaux, au sens de l'égalité bit à bit.

On a la proposition (1), avec $E = "src"$, l'ensemble des code source possibles pour un langage, et $F= "bin"$, l'ensemble des binaires exécutables

Nix ne peut pas garantir que le programme sera sans effets de bords au _runtime_, mais vise à le garantir au _build-time_.

== Nix, le gestionnaire de paquets pur

=== Un _DSL_#footnote[Domain-Specific Language] fonctionnel

Une autre caractéristique que l'on trouve souvent dans la famille de langages fonctionnels est l'omniprésence des _expressions_: la quasi-totalité des constructions syntaxiques forment des expressions valides, et peuvent donc servir de valeur

#table(
  columns: (50%, 50%),
  ```python
  def request(url):
    try:
      response = http_get(url)
    except e:
      response = str(e)
    return process(response)
  ```,
  ```ocaml
  let request url = process (
    try
      http_get(url)
    with e ->
      to_string(e)
  )
  ```,

  [ *Python* (`if` et `else` sont des instructions) ],
  [ *OCaml* (`if` et `else` forment une expression) ],
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

Voici un exemple de définition d'un paquet Nix, appelée _dérivation_ dans le jargon du langage:


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

La dérivation prend ici en entrée le code source (`src-odri-masterboard-sdk`), ainsi que des dépendances, que ce soit des fonctions relatives à Nix même (comme `stdenv.mkDerivation`) pour simplifier la définition de dérivation, ou des dépendances du programme, qu'elles servent à la compilation ou à son exécution (dans ce dernier cas de figure, les dépendances sont inclues ou dynamiquement liées dans le binaire final)

=== Un ecosystème de dépendances

Afin de conserver la reproductibilité même lorsque l'on dépend de bibliothèques tierces, ces dépendances doivent également avoir une compilation reproductible: on déclare donc des dépendances à des paquets Nix, disponibles sur un registre centralisé, _Nixpkgs_ @nixpkgs.

Ainsi, écrire un paquet Nix pour son logiciel demande parfois d'écrire des paquets Nix pour les dépendances de notre projet, si celles-ci n'existent pas encore, et cela récursivement. On peut ensuite soumettre ces autres paquets à Nixpkgs @nixpkgs-contributing afin que d'autres puissent en dépendre sans les réécrire.

Pour ne pas avoir à compiler toutes les dépendances soi-même quand on dépend de paquets sur _Nixpkgs_, il existe un serveur de cache, qui propose des binaires des dépendances, Cachix @cachix

=== Une compilation dans un environnement fixé

Certains aspects de l'environnement dans lequel l'on compile un programme peuvent faire varier le résultat final. Pour éviter cela, Nix limite au maximum les variations d'environnement. Par exemple, la date du système est fixée au 0 UNIX (1er janvier 1990) pendant la compilation#footnote[La date système n'est pas modifiée par Nix, mais il expose une date zéro au processus compilant le logiciel]: le programme compilé ne peut pas dépendre de la date à laquelle il a été compilé.

Quand le _sandboxing_ est activé, Nix isole également le code source de tout accès au réseau, aux autres fichiers du système, ainsi que d'autres mesures, pour améliorer la reproductibilité @nix-sandboxing

==== Un complément utile: compiler en _CI_

Pour aller plus loin, on peut lancer la compilation du paquet Nix en _CI_#footnote[Continuous Integration, lit. intégration continue], c'est-à-dire sur un serveur distant, au lieu de compiler sur sa propre machine. On s'assure donc que l'état de notre machine de développement personnelle n'influe pas sur la compilation, puisque chaque compilation est lancée dans une machine virtuelle vierge @github-runners.

== NixOS, un système d'exploitation à configuration déclarative

Une fois le programme compilé avec ses dépendances, il est prêt à être transféré à l'ordinateur ou la carte de contrôle embarquée sur le robot.

Lorsqu'il y a un ordinateur embarqué, comme par exemple une Raspberry Pi @raspi, il faut choisir un OS sur lequel faire tourner le programme.

Là encore, un OS s'accompagne d'un amas considérable de configuration des différentes parties du système: accès au réseau, drivers, etc.

Sur les distributions Linux classiques tels que Ubuntu ou Debian, cette configuration est parfois stockée dans des fichiers, ou parfois retenue en mémoire, modifiée par l'exécution de commandes.

C'est un problème assez récurrent avec Linux de manière générale: d'un coup, le son ne marche plus, on passe ½h sur un forum à copier-coller des commandes dans un terminal, et le problème est réglé… jusqu'à ce qu'il survienne à nouveau après un redémarrage ou une réinstallation.

Ici, NixOS assure que toute modification de l'état du système est _déclarée_ (d'où l'adjectif "déclaratif") dans des fichiers de configurations, également écrits dans des fichiers `.nix` @nixos-impatient.

Ici encore, cela apporte un gain en terme de reproductibilité: l'état de configuration de l'OS sur lequel est déployé le programme du robot est, lui aussi, rendu reproductible.

== Packaging Nix pour _gz-unitree_

Le packaging pour Nix de _gz-unitree_ lui-même n'est pas très complexe: il s'agit d'un projet C++ / CMake standard @gzu-cmakelists.

Cependant, _gz-unitree_ a deux dépendances principales:

- Gazebo lui-même, à travers `gz-sim`, `gz-sensors`, `gz-common`, `gz-plugin`, `gz-cmake`, etc.
- Le SDK d'Unitree, `unitree_sdk2`

En ce qui concerne le SDK d'Unitree, un paquet Nix a pu être écrit sans trop de soucis, la bibliothèque étant également un projet C++ standard:

```nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  eigen,
}:

stdenv.mkDerivation rec {
  pname = "unitree-sdk2";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "unitreerobotics";
    repo = "unitree_sdk2";
    rev = version;
    hash = "sha256-r05zwhZW36+VOrIuTCr2HLf2R23csmnj33JFzUqz62Q=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [ eigen ];

  meta = {
    description = "Unitree robot sdk version 2. https://support.unitree.com/home/zh/developer";
    homepage = "https://github.com/unitreerobotics/unitree_sdk2";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ nim65s ];
    platforms = lib.platforms.unix;
  };
}
```

Par contre, en ce qui concerne Gazebo, la situation est plus complexe: étant un simulateur système, le projet est bien plus conséquent, et donc plus dur à packager.

Il existe plusieurs tentatives de packaging de Gazebo pour Nix:

- Un _overlay_ ROS (Robot Operating System), qui inclut notamment Gazebo @nixros
- Un package pour _Nixpkgs_ @nixgz @nixgz2 @nixgz3
- Un outil de génération de paquets Nix à partir de paquets ROS ou Gazebo, développé par Guilhem Saurel au sein de l'équipe Gepetto, _gazebros2nix_ @gazebros2nix

Au début du développement de _gz-unitree_, des essais d'utilisation des paquets Nix pour le développement et la compilation ont été réalisés, mais des erreurs subsistaient, en particulier avec Gazebo.
Des efforts supplémentaires sont nécessaires pour empaqueter _gz-unitree_.
