Unitree met à disposition du public un _SDK_#footnote[Kit de développement logiciel (Software Development Kit)] permettant de contrôler ses robots (dont le H1v2). 

== Une base de code partiellement open-source

Le code source du SDK d'unitree est disponible sur _Github_ à https://github.com/unitreerobotics/unitree_sdk2. Cependant, le code source comprend des fichiers binaires déjà compilés:

#figure(
  caption: [Résultat de `tree lib thirdparty` dans le dépot git @sdk2_source_today],
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

#import "@preview/zebraw:0.5.5": zebraw

#figure(
  caption: [Extrait de `cmake/unitree_sdk2Targets.cmake`],
  zebraw(
    numbering-offset: 63 - 1,
    highlight-lines: (4,),
    lang: false,
    background-color: luma(255),
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

== Canaux DDS bas niveau

== Rétroingénierie des binaires

== Un autre bridge existant: `unitree_mujoco`

