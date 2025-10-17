#show figure: set block(spacing: 3em)

Unitree met à disposition du public un _SDK_#footnote[Kit de développement logiciel (Software Development Kit)] permettant de contrôler ses robots (dont le H1v2). 

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

Les logs montrent aussi que les recettes de compilation dépendent de versions précompilées de LibDDSC et LibDDSCXX, dont le code source semble cependant être fourni dans le code source:

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
 
Cependant, l'existance d'une implémentation existante d'un bridge SDK $arrow.lr$ Mujoco a rendu 

== Canaux DDS bas niveau

== Un autre bridge existant: `unitree_mujoco`

