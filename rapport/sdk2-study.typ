#show figure: set block(spacing: 3em)

Unitree met à disposition du public un _SDK_#footnote[Kit de développement logiciel (Software Development Kit)] permettant de contrôler ses robots (dont le H1v2). 

== Canaux DDS

Pour communiquer avec le robot via le réseau, Unitree utilise CycloneDDS, une implémentation par Oracle du standard DDS#footnote[pour Data Distribution Service] @cyclonedds, une technologie de communication bidirectionnelle#footnote[dite "_pub-sub_" pour _publish_/_subscribe_ ] en temps réel, standardisée par l'Object Management Group, OMG @dds. Les messages sont envoyées sur le réseau via UDP et IP.

Les données contenues dans chacun des messages sont spécifiées via un autre format, IDL, également  standardisé par l'OMG @omgidl.

L'intérêt d'un format indépendant du langage de programmation est que l'on peut générer du code décrivant ces données pour plusieurs langages, ce que fait Unitree en distribuant du code C++ et Python.

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
```
)

DDS groupe les mesages dans des _topics_. Les messages sont échangés sur un topic de la manière suivante

/ Lecture: En s'abonnant au topic, on reçoit en temps réel les messages qui sont envoyés dessus
/ Écriture: En publiant des messages sur le topic, on les rend disponibles aux abonnés

#import "@preview/unify:0.7.1": qty

CycloneDDS est capable d'un débit d'environ #qty("1", "GB/s"), pour des messages d'environ #qty("1", "kB") chacun @dds-benchmark. On remarque, en pratique, des messages entre #qty("0.9", "kB") et #qty("1.3", "kB") dans le cas des échanges commandes/état avec le robot

Et enfin, les _topics_ peuvent être isolés d'autres topics via des _domain_#[s].


== Une base de code partiellement open-source

Le code source du SDK d'unitree est disponible sur Github @sdk2_source_today. Cependant, le dépôt git comprend des fichiers binaires déjà compilés:

#figure(
  caption: [Résultat de `tree lib thirdparty` dans le dépot git],
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
```
)

Compiler le SDK nécéssite l'existance de ces fichiers binaires:

#import "@preview/zebraw:0.5.5"
#let zebraw = (..args) => zebraw.zebraw(lang: false, background-color: luma(255), ..args)

#figure(
  caption: [Extrait de `cmake/unitree_sdk2Targets.cmake`],
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
```
))

Ici est défini, via `set_target_properties(... IMPORTED_LOCATION)`, le chemin d'une bibliothèque à lier avec la bibliothèque finale @cmake-imported-location.

On confirme ceci en lançant `mkdir build && cd build && cmake ..` après avoir supprimé le répertoire `lib/` :

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
```
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

Ces constats ont motivé une première tentative de décompilation de ces `libunitree_sdk2.a` pour comprendre le fonctionnement du SDK2, via _Ghidra_ @ghidra.
 
Cependant, la découverte de l'existance d'un bridge officiel SDK $arrows.lr$ Mujoco @unitree_mujoco a rendu cette piste non nécéssaire.

== Un autre bridge existant: `unitree_mujoco`

Unitree propose un "bridge" officiel pour utiliser son SDK avec Mujoco, et ainsi faire du reinforcement learning avec H1v2 en utilisant Mujoco.
