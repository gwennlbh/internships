#import "@preview/fletcher:0.5.8": diagram, edge, node

#show figure: set block(spacing: 3em)

== Le robot _H1v2_ d'Unitree

Le _H1v2_ est un modèle de robot humanoïde créé par la société Unitree.

Il possède plus de 26 degrés de liberté, dont

- 6 dans chaque jambe (3 à la hanche, 2 au talon et un au genou),
- 7 dans chaque bras (3 à l'épaule, 3 au poignet et un au coude) @h1v2

Unitree met à disposition du public un _SDK_#footnote[Kit de développement logiciel (Software Development Kit)] permettant de le contrôler, `unitree_sdk2` @unitree_sdk2

== Canaux DDS

Pour communiquer avec le robot via le réseau, Unitree utilise CycloneDDS, une implémentation par Oracle du standard DDS#footnote[pour Data Distribution Service] @cyclonedds. DDS est une technologie de communication bidirectionnelle#footnote[dite "_pub-sub_" pour _publish_/_subscribe_ ] en temps réel, standardisée par l'Object Management Group, OMG @dds. Les messages sont envoyés sur le réseau via UDP et IP.

Les données contenues dans chacun des messages sont spécifiées via un autre format, IDL, également  standardisé par l'OMG @omgidl.

L'intérêt d'un format indépendant du langage de programmation est que l'on peut générer du code décrivant ces données dans plusieurs langages de programmation, ce que fait Unitree en distribuant un SDK en C++ et en Python.

Par exemple, les messages permettant de contrôler les moteurs du H1v2 sont définis ainsi

#figure(
  caption: [`LowCmd.idl`, traduit depuis sa conversion en C++ @lowcmd_hpp],
  ```c
  struct MotorCmd
  {
    uint8 mode;
    float q;
    float dq;
    float tau;
    float kp;
    float kd;
    unsigned long reserve;
  };

  struct Cmd
  {
    uint8 mode_pr;
    uint8 mode_machine;
    MotorCmd motor_cmd[35];
    unsigned long reserve[4];
    unsigned long crc;
  };
  ```,
)

DDS groupe les messages dans des _topics_. Les messages sont échangés sur un topic de la manière suivante

/ Lecture: En s'abonnant au topic, on reçoit en temps réel les messages qui sont envoyés dessus
/ Écriture: En publiant des messages sur le topic, on les rend disponibles aux abonnés

#import "@preview/unify:0.7.1": qty

CycloneDDS est capable d'un débit d'environ #qty("1", "GB/s"), pour des messages d'environ #qty("1", "kB") chacun @dds-benchmark. On remarque, en pratique, des tailles de message entre #qty("0.9", "kB") et #qty("1.3", "kB") dans le cas des échanges commandes/état avec le robot.

Et enfin, les topics peuvent être isolés d'autres topics via des _domain_#[s], identifiés par un numéro. Deux topics portant le même nom reste isolés si ils sont sur deux domaines différents.


== Une base de code partiellement open-source

Le code source du SDK d'Unitree est disponible sur Github @sdk2_source_today. Cependant, le dépôt git comprend des fichiers binaires déjà compilés:

#figure(
  caption: [Résultat de `tree lib/ thirdparty/` dans le dépot git],
  ```
  lib
  ├── aarch64
  │   └── libunitree_sdk2.a
  └── x86_64
      └── libunitree_sdk2.a
  thirdparty
  ├── CMakeLists.txt
  ├── include
  │   └── ...
  └── lib
      ├── aarch64
      │   ├── libddsc.so
      │   ├── libddsc.so.0 -> libddsc.so
      │   ├── libddscxx.so
      │   └── libddscxx.so.0 -> libddscxx.so
      └── x86_64
          ├── libddsc.so
          ├── libddsc.so.0 -> libddsc.so
          ├── libddscxx.so
          └── libddscxx.so.0 -> libddscxx.so
  ```,
)

Compiler le SDK nécéssite l'existance de ces fichiers binaires:

#import "@preview/zebraw:0.6.0"
#let zebraw = (..args) => zebraw.zebraw(
  lang: false,
  background-color: luma(255),
  ..args,
)

#figure(
  caption: [Extrait de `cmake/unitree_sdk2Targets.cmake` @unitree_sdk2],
  kind: raw,
  zebraw(
    numbering-offset: 63 - 1,
    highlight-lines: (4,),
    ```cmake
    # Create imported target unitree_sdk2
    add_library(unitree_sdk2 STATIC IMPORTED GLOBAL)
    set_target_properties(unitree_sdk2 PROPERTIES
      IMPORTED_LOCATION ${_IMPORT_PREFIX}/lib/libunitree_sdk2.a
      INTERFACE_INCLUDE_DIRECTORIES "${_IMPORT_PREFIX}/include;${_IMPORT_PREFIX}/include"
      INTERFACE_LINK_LIBRARIES "ddsc;ddscxx;Threads::Threads"
      LINKER_LANGUAGE CXX
    ```,
  ),
)

Ici est défini, via `set_target_properties(... IMPORTED_LOCATION)`, le chemin d'une bibliothèque à lier avec la bibliothèque finale @cmake-imported-location. Ici, c'est un des fichiers pré-compilés que l'on lie.

On confirme cette nécéssite en lançant `mkdir build && cd build && cmake ..` après avoir supprimé le répertoire `lib/` :

#{
  show regex(".*CMake Error.*"): set text(fill: red)
  show regex(".*not found.*"): set text(fill: red)

  zebraw(
    highlight-lines: (18, 19),
    numbering: false,
    ```
    -- The C compiler identification is GNU 13.3.0
    -- The CXX compiler identification is GNU 13.3.0
    -- Detecting C compiler ABI info
    -- Detecting C compiler ABI info - done
    -- Check for working C compiler: /usr/bin/cc - skipped
    -- Detecting C compile features
    -- Detecting C compile features - done
    -- Detecting CXX compiler ABI info
    -- Detecting CXX compiler ABI info - done
    -- Check for working CXX compiler: /usr/bin/c++ - skipped
    -- Detecting CXX compile features
    -- Detecting CXX compile features - done
    -- Setting build type to 'Release' as none was specified.
    -- Current system architecture: x86_64
    -- Performing Test CMAKE_HAVE_LIBC_PTHREAD
    -- Performing Test CMAKE_HAVE_LIBC_PTHREAD - Success
    -- Found Threads: TRUE
    -- Importing: /home/glebihan/playground/unitree_sdk2/thirdparty/lib/x86_64/libddsc.so
    -- Importing: /home/glebihan/playground/unitree_sdk2/thirdparty/lib/x86_64/libddscxx.so

    CMake Error at CMakeLists.txt:42 (message):
    Unitree SDK library for the architecture is not found


    -- Configuring incomplete, errors occurred!
    ```,
  )
}

Les logs montrent aussi que les recettes de compilation dépendent de versions précompilées de LibDDSC et LibDDSCXX, dont le code source semble cependant être fourni avec _unitree\_sdk2_:

```sh-session
thirdparty/include/dds
├── config.h
├── ddsc
│   ├── dds_basic_types.h
│   ├── dds_data_allocator.h
│   ├── dds_internal_api.h
│   ├── dds_loan_api.h
│   ├── dds_opcodes.h
│   ├── dds_public_alloc.h
...
```

Ces particularités laissent planner quelques doutes sur la nature open-source du code: ces binaires requis sont-ils seulement présent pour améliorer l'expérience développeur en accélererant la compilation, ou "cachent"-ils du code non public?

Ces constats ont motivé une première tentative de décompilation de ces `libunitree_sdk2.a` pour comprendre le fonctionnement du SDK, via _Ghidra_ @ghidra.

Cependant, la découverte de l'existance d'un bridge officiel SDK $arrows.lr$ Mujoco @unitree_mujoco a rendu l'exploration de cette piste non nécéssaire.

== Un autre bridge existant: `unitree_mujoco`

Unitree propose un bridge officiel pour utiliser son SDK avec Mujoco.

Le fonctionnement d'un bridge est au final assez similaire, quelque soit le simulateur pour lequel on l'écrit: il s'agit d'envoyer l'état du robot au simulateur, et de réagir quand le simulateur envoie des ordres de commandes.

#figure(caption: "Fonctionnement usuel du SDK", diagram({
  node((0, 0), $Pi$)
  node((1, 0), "SDK")
  node((2, 0), "robot")

  edge((0, 0), (0, 0), "<-", bend: 130deg, loop-angle: 180deg)[]
  edge((2.25, 0), (2.25, 0), "->", bend: -130deg, loop-angle: -180deg)[]


  for i in range(0, 2) {
    edge((i, 0), (i + 1, 0), "->", shift: 3pt)[ordres]
    edge((i, 0), (i + 1, 0), "<-", shift: -3pt, label-side: right)[état]
  }
}))

Un bridge se substitue au robot physique, interceptant les ordres du SDK et les traduisants en des appels de fonctions provenant de l'API du simulateur, et symmétriquement pour les envois d'états au SDK. On peut apparenter le fonctionnement d'un bridge à celui d'une attaque informatique de type "Man in the Middle" (MitM).


#figure(caption: [Fonctionnement via _unitree\_mujoco_ du SDK], diagram({
  node((0, 0), $Pi$)
  node((1, 0), "SDK")
  node((2, 0))[`unitree_mujoco`]
  node((3, 0), "Mujoco")

  edge((0, 0), (0, 0), "<-", bend: 130deg, loop-angle: 180deg)[]
  edge((3.25, 0), (3.25, 0), "->", bend: -130deg, loop-angle: -180deg)[]

  for i in range(0, 3) {
    edge((i, 0), (i + 1, 0), "->", shift: 3pt)[ordres]
    edge((i, 0), (i + 1, 0), "<-", shift: -3pt, label-side: right)[état]
  }

  edge((0, 1), (2, 1), "|-|", label-side: right)[API du SDK]
  edge((2, 1), (3, 1), "|-|", label-side: right)[API de Mujoco]
}))

Le but est de faire la même chose avec notre propre bridge. Le code du bridge Mujoco existant est utile car un bridge, se situant par définition à la frontière entre deux APIs, fait usage des deux APIs.

Écrire un bridge Gazebo pour le même SDK implique donc de changer "API de Mujoco" par "API de Gazebo", mais le code faisant usage du SDK d'Unitree reste le même.


#figure(caption: [Fonctionnement via _gz-unitree_ du SDK], diagram({
  node((0, 0), $Pi$)
  node((1, 0), "SDK")
  node((2, 0))[`gz-unitree`]
  node((3, 0), text(fill: blue)[Gazebo])

  edge((0, 0), (0, 0), "<-", bend: 130deg, loop-angle: 180deg)[]
  edge(
    (3.25, 0),
    (3.25, 0),
    "->",
    bend: -130deg,
    loop-angle: -180deg,
    stroke: blue,
  )[]

  for i in range(0, 3) {
    let col = if i == 2 { blue } else { black }
    edge((i, 0), (i + 1, 0), "->", shift: 3pt, stroke: col, text(
      fill: col,
    )[ordres])
    edge(
      (i, 0),
      (i + 1, 0),
      "<-",
      shift: -3pt,
      stroke: col,
      label-side: right,
      text(fill: col)[état],
    )
  }

  edge((0, 1), (2, 1), "|-|", label-side: right)[API du SDK]
  edge((2, 1), (3, 1), "|-|", stroke: blue + 1.25pt, label-side: right, text(
    fill: blue,
  )[*API de Gazebo*])
}))

Le bridge de Mujoco fonctionne en interceptant les messages sur le canal `rt/lowcmd` et en en envoyant dans le canal `rt/lowstate`, qui correspondent respectivement aux commandes envoyées au robot et à l'état (angles des joints, moteurs, valeurs des capteurs, etc) reçu depuis le robot.

Le `low` indique que ce sont des messages bas-niveau. Par exemple, `rt/lowcmd` correspond directement à des ordres en valeurs de couple pour les moteurs, au lieu d'envoyer des ordres plus évolués, tels que "se déplacer de $x$ mètres en avant" @h1-motion-services

Les ordres dans `rt/lowcmd` sont ensuite traduits en appels de fonctions de Mujoco pour mettre à jour l'état du robot simulé, et de messages `rt/lowstate` sont créés à partir des données fournies par Mujoco.

Étant donné le modèle _pub/sub_ de DDS, on parle de _pub(lication)_ de message, et de _sub(scription)_#footnote[abonnement] aux messages d'un canal (pour les recevoir).

#figure(
  caption: [Cycle de vie de la simulation avec le bridge pour Mujoco],
  diagram({
    node(name: <sdk>, (0, 0))[SDK]
    node(
      enclose: ((1, 1), (-1, 1)),
      stroke: blue,
      inset: 10pt,
      snap: false,
      text(fill: blue)[Canaux \ DDS],
    )
    node(name: <lowcmd>, (1, 1))[`rt/lowcmd`]
    node(name: <lowstate>, (-1, 1))[`rt/lowstate`]
    node(
      name: <bridge>,
      enclose: ((1, 2), (-1, 2)),
      stroke: black,
      inset: 10pt,
    )[Bridge]
    node(name: <mujoco>, (0, 3))[Mujoco]


    edge(<sdk>, <lowcmd>, "->", bend: 30deg)[pub]
    edge(<lowcmd>, (1, 2), "-->", bend: 20deg)[via sub]
    edge((1, 2), <mujoco>, "->", bend: 20deg, `data->ctrl[i] = ...`)

    edge(<sdk>, <lowstate>, "<--", bend: -30deg)[via sub]
    edge(<lowstate>, (-1, 2), "<-", bend: -20deg)[pub]
    edge((-1, 2), <mujoco>, "<-", bend: -20deg, `... = data->sensordata[i]`)

    edge(
      <mujoco>,
      <mujoco>,
      "->",
      bend: 130deg,
      loop-angle: -90deg,
      `mj_step(model, data)`,
    )
  }),
)

Le but est donc de reproduire un cycle de vie équivalent, mais en remplaçant la partie spécifique à Mujoco par une partie adaptée à Gazebo.
