#import "@preview/zebraw:0.5.5"
#import "@preview/fletcher:0.5.8": diagram, edge, node
#import "@preview/cetz:0.4.2"
#import "./utils.typ": dontbreak, refneeded, trimmed-image
#show figure: set block(spacing: 2em)
#let zebraw = (..args) => zebraw.zebraw(
  lang: false,
  background-color: luma(255).opacify(0%),
  ..args,
)

// Utile: message marquant le début du dev de gz-unitree, 23 juin 2025
// https://matrix.to/#/!MmlaUevGqfiZYSHREv:laas.fr/$omjzydhckQuIVkcNBw0LTYVT7Td1C9UeLqbIisJAnFg?via=laas.fr

En se basant sur _unitree\_mujoco_, il a donc été possible de réaliser un bridge pour Gazebo.

== Établissement du contact

Une première tentative a été de suivre la documentation de CycloneDDS @cyclonedds-helloworld pour écouter sur le canal `rt/lowcmd`, en récupérant les définitions IDL des messages, disponibles sur le dépot `unitree_ros2`#footnote[`unitree_mujoco` n'avait pas encore été découvert] @unitree_ros2

Malheureusement, cette solution s'est avérée infructueuse, à cause d'une erreur sur les domaines DDS utilisés (ce qui sera compris plus tard).

On change d'approche, en préférant plutôt utiliser les abstractions fournies par le SDK de Unitree (cf @receive-lowcmd et @send-lowstate)

Enfin, si un pare-feu est actif, il faut autoriser le traffic UDP l'intervalle d'addresses IP `224.0.0.0/4`. Par exemple, avec _ufw_ @ufw

```bash
sudo ufw allow in proto udp from 224.0.0.0/4
sudo ufw allow in proto udp to 224.0.0.0/4
```

#dontbreak(grid(
  columns: (1.5fr, 1fr),
  gutter: 2em,
  [

    Pour arriver à ces solutions, _Wireshark_ @wireshark s'est avéré utile, étant capable d'inspecter du traffic RTPS#footnote[Le protocole sur lequel est construit DDS @dds],


    C'est notamment grâce à ce traçage des paquets que le problème de domaine DDS a été découvert: notre _subscriber_ DDS était réglé sur le domaine anonyme (ID aléatoire représenté par un 0 lors de la configuration) alors que le SDK d'Unitree communique sur le domaine d'ID 1.

    C'est aussi Wireshark qui nous a permis de voir quels étaient les types IDL utilisés pour les messages.
  ],
  figure(
    caption: [_Wireshark_ permet de visualiser des méta-données sur les paquets RTPS],
    stack(
      spacing: 1em,
      image("./wireshark-wrong-domain.png"),
      image("./wireshark-message-type.png"),
    ),
  ),
))

Voici une trace wireshark d'un échange usuel entre commandes (`rt/lowcmd`) et états (`rt/lowstate`)

#let img = image("./wireshark-trace.png")
// https://forum.typst.app/t/how-to-blend-a-color-with-an-image-and-make-the-image-transparent/1677/5
#let overlayed-img = contents => layout(bounds => {
  let size = measure(img, ..bounds)
  img
  place(top + left, block(..size, contents))
})

#figure(
  caption: [Trace de paquets RTPS sur _Wireshark_],
  overlayed-img[
    #diagram(spacing: (4.54pt, 2.75pt), {
      node((0, 0))[]
      let annotations-x = 80
      let annotate = (y-start, y-end, label) => edge(
        (annotations-x, y-start),
        "|-|",
        (annotations-x, y-end),
        label-fill: white,
        label-side: left,
        label,
      )

      annotate(3, 20)[Attente]
      annotate(20, 60)[Initialisation]
      annotate(60, 100)[Échange `rt/` \ `lowstate` $arrows.lr$ `lowcmd`]
    })
  ],
)



== Installation du plugin dans Gazebo

Un _system plugin_ Gazebo consiste en la définition d'une classe héritant de `gz::sim::System` et d'interfaces permettant notamment d'exécuter notre code avant ou après un pas de temps du simulateur (avec `gz::sim::ISystem`{`Pre`,`Post`}`Update`)

#figure(
  caption: [Fichier header pour le plugin],
  ```cpp
  #include <gz/sim/System.hh>
  namespace gz_unitree
  {
      class UnitreePlugin :
          public gz::sim::System,
          public gz::sim::ISystemPreUpdate
      {
      public:
          UnitreePlugin();
      public:
          ~UnitreePlugin() override;
      public:
          void PreUpdate(const gz::sim::UpdateInfo &_info,
                         gz::sim::EntityComponentManager &ecm) override;
      };
  }
  ```,
)

Il faut ensuite implémenter la classe puis appeler une macro ajoutant le plugin à Gazebo

```cpp
#include <gz/plugin/Register.hh>

... // class implementation

GZ_ADD_PLUGIN(
    UnitreePlugin,
    gz::sim::System,
    UnitreePlugin::ISystemPreUpdate)
```

Enfin, on active le plugin en le référençant dans le fichier SDF @sdf-plugin, qui décrit l'environnement des simulations (objets, éclairage, etc)

#zebraw(
  numbering: false,
  highlight-lines: (..range(3, 5),),
  ```xml
  <sdf version='1.11'>
  <world name="default">
    <plugin filename="gz-unitree" name="gz_unitree::UnitreePlugin">
    </plugin>
  </world>
  <model name='h1_description'>
    <link name='pelvis'>
      <inertial>
      ...
  ```,
)

Avec `filename` le chemin vers le plugin compilé, qui sera cherché dans les répertoires spécifiés par `GZ_SIM_SYSTEM_PLUGIN_PATH` @gz-system-plugin-path @sdf-plugin-filename.


== Architecture du plugin

Le plugin consiste en trois parties distinctes:

- Le "branchement" dans les phases de simulation de Gazebo, par l'implémentation de méthodes de `gz::sim::System`
- L'interaction avec les canaux DDS du SDK d'Unitree
- Les données et méthodes internes au plugin

En plus de cela, il y a bien évidemment la politique de contrôle $Pi$, qui interagit avec le robot (qu'il soit réel, ou simulé) via le SDK, et donc via les canaux DDS.

#let legend = (
  ..descriptions,
) => grid(
  columns: (1fr, 3fr),
  align: left,
  row-gutter: 0.5em,
  ..descriptions
    .pos()
    .map(((arrow, desc)) => (
      diagram(edge((0, 0), arrow, (0.75, 0))),
      desc,
    ))
    .flatten()
)

#let architecture = (
  caption,
  group-inset: 12pt,
  group-color: luma(80),
  show-legend: true,
  ..edges,
) => figure(caption: caption, pad(
  y: 10pt + group-inset,
  diagram(
    debug: false,
    node-stroke: 0.5pt,
    edge-corner-radius: 6pt,
    {
      let group = (
        nodes,
        label,
        alignment: bottom + center,
        name: none,
      ) => node(
        name: name,
        enclose: nodes,
        snap: if name == none { false } else { 1 },
        inset: group-inset,
        stroke: group-color.lighten(75%) + 2pt,
        align(alignment, move(
          dy: 2 * group-inset * if alignment.y == bottom { 1 } else { -1 },
          text(fill: group-color, label),
        )),
      )

      let subtitled = (title, subtitle) => [#title \ #text(
          size: 0.8em,
          subtitle,
        )]

      node(name: <configure>, (0, 1), `::Configure`)
      node(name: <preupdate>, (0, 2), `::PreUpdate`)
      group(
        name: <gz>,
        (<configure>, <preupdate>),
        `gz::sim::System`,
        alignment: top + center,
      )


      node(
        name: <channelfactory>,
        enclose: ((1, 0), (2, 0)),
        inset: 8pt,
        subtitled(`ChannelFactory`, [domaine 1, interface `lo`]),
      )
      node(name: <publisher>, (1, 1), inset: 8pt, subtitled(
        `ChannelPublisher`,
        [canal `rt/lowstate`],
      ))
      node(name: <subscriber>, (2, 1), inset: 8pt, subtitled(
        `ChannelSubscriber`,
        [canal `rt/lowcmd`],
      ))
      group(
        name: <dds>,
        (<channelfactory>, <publisher>, <subscriber>),
        alignment: top + center,
      )[Unitree SDK]


      node(name: <gzclock>, (1, 5), subtitled(
        `::TickHandler`,
        [topic Gazebo `/clock`],
      ))
      node(name: <gzimu>, (2, 5), subtitled(
        `::IMUHandler`,
        [topic Gazebo `/imu`],
      ))
      node(name: <lowstate>, (1, 2), `::LowStateWriter`)
      node(name: <lowcmd>, (2, 2), `::CmdHandler`)
      node(name: <statebuf>, (1, 3), subtitled("State buffer", `statebuf`))
      node(name: <cmdbuf>, (2, 3), subtitled("Commands buffer", `cmdbuf`))
      group((
        <lowstate>,
        <lowcmd>,
        <statebuf>,
        <cmdbuf>,
        <gzclock>,
        <gzimu>,
      ))[Plugin internals]

      node(name: <policy>, (0, -1), $Pi$)

      for e in edges.pos() {
        e
      }


      if show-legend {
        node((0, 5), stroke: none, width: 15em, fill: white, legend(
          ("-->", "Message DDS"),
          ("..>", "Message Gazebo"),
          ("@->", "Désynchronisation"),
        ))
      }
    },
  ),
))

#architecture([Phase d'initialisation du plugin], show-legend: false, {
  edge(
    <configure>,
    "u",
    <channelfactory>,
    "->",
    label-side: left,
    label-pos: 50%,
  )[appelle]
  edge(<channelfactory>, "->", <publisher>)[initialise]
  edge(<channelfactory>, "->", <subscriber>)[initialise]
  edge(<publisher>, "<->", <lowstate>)[`std::bind`]
  edge(<subscriber>, "<->", <lowcmd>)[`std::bind`]
  edge(<configure>, "d,d,d,r", <gzclock>, "->", label-pos: 85%)[démarre]
  edge(
    <configure>,
    "d,d",
    (0, 3.75),
    "r,r",
    <gzimu>,
    "->",
    label-pos: 75%,
  )[démarre]
})

On commence par instancier un contrôleur dans le domaine DDS n°1, sur l'interface réseau `lo`#footnote[interface dite "loopback", qui est locale à l'ordinateur: ici, le simulateur et la politique de contrôle tournent sur la même machine, donc les messages DDS n'ont pas besoin de "sortir" de celle-ci]

On lui associe:

- Un _publisher_, chargé d'envoyer périodiquement des messages sur `rt/lowstate` en appellant la méthode `LowStateWriter`
- Un _subscriber_, chargé d'appeller la méthode `CmdHandler` avec chaque message arrivant sur `rt/lowcmd`.

On démarre aussi deux autres #emph[subscriber]s, qui sont eux chargés d'écouter des messages sur les topics Gazebo `/clock` et `/imu`, ce qui permet de récupérer le tick de simulation et les valeurs du capteur IMU#footnote[Inertial Measurement Unit, appelée "Centrale intertielle" en français], que l'on a préalablement fixé au modèle du robot en le déclarant dans le fichier SDF chargé par Gazebo. Le capteur IMU donne des informations spatiales importantes sur la position et la vitesse du robot.

Les topics Gazebo sont un autre moyen de communcation inter-processus asynchrone par pub/sub, similaire à DDS @gz-topics. Gazebo utilise Protobuf pour définir les types des messages @protobuf @gz-messages, qui joue ici le même role qu'IDL dans DDS. Les topics Gazebo sont basés sur un réseau décentralisé de nœuds, chaque nœud pouvant indépendamment publier et/ou recevoir des messages.

Cette initialisation est faite à la phase de configuration du plugin par Gazebo, via l'implémentation de la méthode `::Configure` du plugin.

En pratique, on utilise `std::bind` @cpp-bind pour fixer l'instance d'`UnitreePlugin` et ainsi passer des méthodes de la classe comme des simples fonctions.

#figure(
  caption: [Création d'un _subscriber_ à `rt/lowcmd` et d'un _publisher_ sur `rt/lowstate` dans `UnitreePlugin::Configure`],
  text(size: 0.8em, grid(
    columns: 2,
    gutter: 1em,
    ```cpp
      auto subscriber = ChannelSubscriberPtr<LowCmd_>(
        new ChannelSubscriber<LowCmd_>("rt/lowcmd")
      );

      auto handler = std::bind(
        &UnitreePlugin::CmdHandler,
        this,
        std::placeholders::_1
      )

      subscriber->InitChannel(handler, 1);
    ```,
    ```cpp
      auto publisher = ChannelPublisherPtr<LowState_>(
        new ChannelPublisher<LowState_>("rt/lowstate")
      );

      publisher->InitChannel();

      this->publisher_thread = CreateRecurrentThreadEx(
        "low_state_writer",
        UT_CPU_ID_NONE,
        500,
        &UnitreePlugin::LowStateWriter,
        this
      );
    ```,
  )),
)

== Calcul des nouveaux couples des moteurs

Pour appliquer une commande à un moteur, on calcule la force effective que le moteur doit appliquer:

$
  tau =
  underbracket(tau_"ff", "stabilité") +
  underbracket(K_p Delta q, "propertionnelle") +
  underbracket(K_d Delta dot(q), "dérivative")
$


Avec

/ $tau$: pour _torque_, le couple à donner au moteur
/ $tau_"ff"$: le $tau$ "feed-forward". Particulièrement utile pour les robots humanoïdes qui doivent rester debout. Dans ces cas, on parle parfois de _gravity compensation part_ @pffc
/ $Delta q$: écart d'angle de rotation du moteur entre la consigne et l'état actuel
/ $Delta dot(q)$: vitesse de changement de la consigne#footnote[

    #let ddt = derivee => $ ( op("d") #derivee ) / ( op("d") t ) $

    On a bien $ddt(Delta q) = Delta dot(q)$ par linéarité de la dérivation temporelle:

    $ ddt(Delta q) = ddt(q_"new" - q_"old") = ddt(q_"new") - ddt(q_"old") = Delta ddt(q) = Delta dot(q) $

  ]
/ $K_p$: prépondérance de la partie proportionelle
/ $K_p$: prépondérance de la partie dérivée

Cette équation met à jour $tau$ pour rapprocher l'état actuel du moteur de la nouvelle consigne, en prenant en compte

- L'erreur sur l'angle $Delta q$ (partie proportionelle).
- L'erreur sur la vitesse de changement de $Delta q$ (partie dérivative). Cette prise en compte de la vitesse permet de lisser les changements appliqués aux moteurs.
- Un couple dit de _feed-forward_, $tau_"ff"$, qui permet le maintient du robot à un état stable. On pourrait le déterminer en lançant une première simulation, avec pour objectif le maintient debout. Une fois la stabilité atteinte, on relève les couples des moteurs. Intuitivement, on peut voir $tau_"ff"$ comme un manière de s'affranchir de la partie "maintient debout" dans l'expression de la commande, similairement à la mise à zéro ("tarer") d'une balance.

On contrôle la prépondérance des deux erreurs dans le calcul de la nouvelle consigne grâce à deux coefficients, $K_p$ et $K_d$.


== `rt/lowcmd` <receive-lowcmd>


On trouve dans les messages `rt/lowcmd` les champs nécéssaires à au calcul de $tau$ @h1-rt-lowcmd comme décrit précédemment:

#let greyedout = content => text(fill: luma(120), emph(content))
#let undocumented = greyedout[Non documenté]
#table(
  // columns: (1.5fr, 0.5fr, 3fr, 2fr),
  columns: 3,
  stroke: none,
  inset: 6pt,

  "Champ", "Type", "Description",
  table.hline(),

  // `mode_pr`, ${0, 1}$, undocumented,
  // `mode_machine`, ${0, 1}$, undocumented,
  // `reserve`, $NN^4$, undocumented,
  // [], [], greyedout[Autres champs inutilisés],
  `crc`,
  $NN$,
  [Somme de contrôle CRC32, pourrait éventuellement servir à éviter de prendre en compte des messages corrompus],
  `motor_cmd`,
  $"struct."^(35)$,
  [Paramètres de commande pour chacun des 35 moteurs],
  [`  ` `.q`, `.dq`, `.tau`, `.kp` et `.kd`],
  $RR$,
  [Respectivement $q$, $dot(q)$, $tau_"ff"$, $K_p$ et $K_d$],
)

Cette équation se rapproche des modèles de type PID (_proportional-integrative-derivative_) @control-pid, avec le terme intégratif remplacé par $tau_"ff"$, ce qui en fait une expression plus adaptée pour les politiques avec des mouvements non-brusques: le terme intégratif apporte une capacité d'instabilité qui complexifie l'entraînement #refneeded


#figure(
  caption: [Implémentation de la mise à jour de $tau$],
  ```cpp
    // Avec i l'indice du moteur
    auto force = cmdbuf->tau_ff.at(i) +                               // tau_ff
       cmdbuf->kp.at(i) * (                                           // K_p
         cmdbuf->q_target.at(i) - lowstate.motor_state().at(i).q()    // Delta q
       ) +
       cmdbuf->kd.at(i) * (                                           // K_d
         cmdbuf->dq_target.at(i) - lowstate.motor_state().at(i).dq()  // Delta q.
       );

    std::vector<double> torque = {force};
    joint.SetForce(ecm, torque);
  ```,
)

// === Réception des commandes <receive-lowcmd>

Lorsqu'un message, publié par $Pi$ (1A) et contenant des ordres pour les moteurs, arrive sur `rt/lowcmd`, `ChannelSubscriber` appelle `::CmdHandler` (2, 3), et modifie un _buffer_ (4) contenant la dernière commande reçue. Ensuite, Gazebo démarre un nouveau pas de simulation. Avant de faire ce pas, il appelle la méthode `::PreUpdate` sur notre plugin, qui vient chercher la commande stockée dans le _buffer_ (1B), et applique cette commande sur le modèle du robot, animé par le simulateur.


#architecture([Phase de réception des commandes], {
  edge(
    <policy>,
    (2.25, -1),
    (2.25, 0),
    <channelfactory.east>,
    "-->",
    label-pos: 5%,
  )[(1A) publish]
  edge(
    <policy>,
    (2.25, -1),
    (2.25, 0),
    <channelfactory.east>,
    stroke: none,
    label-pos: 60%,
    label-side: left,
  )[(1A) subscription]
  edge(<channelfactory.east>, (2, 0), <subscriber>, "->", label-pos: 80%)[(2)]
  edge(<subscriber>, "->", <lowcmd>, label-side: right)[(3)]
  edge(<lowcmd>, "->", <cmdbuf>)[(4)]
  // edge(<lowcmd.east>, "r,d,d,l,l,l,l,l,l,u,u,u", <preupdate>, "->", label-side: left)[(5)]
  edge(<preupdate>, "d,d,r,r", <cmdbuf>, "<-@")[(1B)]
})

On notera que (1B) s'exécute _parallèlement_ au reste des étapes: la boucle de simulation de Gazebo est indépendante de la boucle de mise à jour de la politique.


/ Si `::PreUpdate` est plus fréquente: Le simulateur appliquera plusieurs fois la même commande, le buffer `cmdbuf` n'ayant pas été modifié.

/ Si `::PreUpdate` est moins fréquente: Certaines commandes seront ignorées par Gazebo, qui ne vera pas la valeur du buffer `statebuf` avant qu'il change de nouveau.

// L'initialisation du subscriber se fait pendant l'initialisation du plugin, c'est à dire dans `UnitreePlugin::Configure`. On relie la réception d'un message à une fonction, qui est ici une méthode, `UnitreePlugin::CmdHandler`.
//
// #dontbreak[
//
// ```cpp
// ...
//
// void UnitreePlugin::Configure()
// {
// ```
//
// Instanciation d'un canal
//
// ```cpp
//     ChannelFactory::Instance()->Init(1, "lo" /* loopback interface */);
// ```
//
// Création de $x |-> mono("CmdHandler")(mono("this"), x)$. L'utilitaire `std::bind` permet de passer à `InitChannel` une fonction simple
//
// ```cpp
//     auto handler = std::bind(
//       &UnitreePlugin::CmdHandler,
//       this,
//       std::placeholders::_1
//     )
// ```
//
// Création du subscriber
//
// ```cpp
//     auto subscriber = ChannelSubscriberPtr<LowCmd_>(
//       new ChannelSubscriber<LowCmd_>("rt/lowcmd")
//     );
//
//
//     subscriber->InitChannel(handler, 1);
// }
// ```
//
// Définition du handler
//
// ```cpp
// void UnitreePlugin::CmdHandler(const void *msg)
// {
//     LowCmd_ _cmd = *(const LowCmd_ *)msg;
//
//     // Remplissage du buffer interne à la classe
//     MotorCommand motor_command_tmp;
//     for (size_t i = 0; i < H1_NUM_MOTOR; ++i)
//     {
//       motor_command_tau_ff[i] = _cmd.motor_cmd()[i].tau();
//       ...
//     }
//
//     this->motor_command_buffer.SetData(motor_command_tmp);
// }
// ```
//
// ]


== `rt/lowstate`

=== Construction d'un message `rt/lowstate`

La documentation d'Unitree liste l'ensemble des champs disponibles dans un message `rt/lowstate`, c'est-à-dire l'ensemble des données que l'on doit récupérer afin de construire nos messages d'état @h1-rt-lowstate:


#let undocumented = text(fill: luma(120), emph("Non documenté"))
#let empty = text(fill: luma(120), emph("Laissé vide"))
#table(
  // columns: (1.5fr, 0.5fr, 3fr, 2fr),
  columns: 4,
  stroke: none,
  inset: 6pt,

  "Champ", "Type", "Description", "Où récupérer la valeur",
  table.hline(),

  `version`,
  $NN^2$,
  undocumented,
  empty,

  `mode_pr`, ${0, 1}$, [Défini sur 0 par défaut], [0],

  `mode_machine`, ${4, 6}$, [Défini sur 6 par défaut], [6],

  `tick`,
  $NN quad ("ms")$,
  [#undocumented, probablement le temps écoulé depuis le début de la simulation],
  [Messages `gz::msgs::Clock` sur le topic Gazebo `/clock` ],

  `wireless_remote`, ${0, 1}^(40)$, undocumented, empty,

  `reserve`, $NN^4$, undocumented, empty,

  `crc`,
  $NN$,
  [Somme de contrôle du message, utilisant _CRC32_. ],
  [Implémentation de CRC32 par Unitree #footnote[
      Une implémentation ad-hoc existe dans le code source de `unitree_sdk2` @sdk2-crc et de `unitree_mujoco` @muj-crc, elle est également donnée en @crc32core ]],

  `imu_state…`,
  "struct.",
  [Valeurs des capteurs intertiels du robot],
  [Messages `gz::msgs::IMU` sur le topic Gazebo `/imu`],

  `  .quaternion`,
  $RR^4$,
  [Posture dans l'espace du robot, dans l'ordre $(w, x, y, z)$],
  [`w`, `x`, `y` et `z` sur  `.orientation()`],

  `  .rpy`,
  $RR^3$,
  [Angle d'Euler du robot, dans l'ordre $(r, p, y)$],
  `.linear_acceleration()`,

  `  .gyroscope`,
  $RR^3$,
  [Gyroscope],
  [
    En utilisant les valeurs de `.orientation()`:
    #math.equation(
      numbering: none,
      block: true,
      $
        vec(
          delim: #("[", "]"),
          gap: #0.5em,
          "atan"_2(2(w x + y z), 1 - 2 (x^2 + y^2) ),
          "asin"(2 (w y - z x)),
          "atan"_2(2(w z + x y), 1 - 2(y^2 + z^2))
        )
      $,
    )
  ],

  `  .accelerometer`, $RR^3$, [Accéléromètre], `.angular_velocity()`,

  `motor_state…`,
  [$"struct."^(35)$],
  [Etat de chaque moteur],
  `gz::sim::Model(…)→joints`,

  `  .mode`,
  ${0, 1}$,
  [Modes de contrôle pour le moteur électrique. $0$ pour "Brake" et $1$ pour "FOC#footnote[Field-Oriented Control]"],
  [0],

  `  .q`,
  $RR quad ("rad")$,
  [Angle de rotation du moteur],
  `.Position()`,

  `  .dq`,
  $RR quad ("rad" dot "s"^(-1))$,
  [Angle de rotation du moteur],
  `.Velocity()`,

  `  .ddq`,
  $RR quad ("rad" dot "s"^(-2))$,
  [Angle de rotation du moteur],
  [#empty#footnote[Tant que nos politiques n'ont pas besoin de ces champs, le SDK semble fonctionner avec des valeurs vides] <empty-why>],

  `  .tau_est`,
  $RR quad ("N" dot "m")$,
  [Estimation du couple exercé par le moteur],
  [#empty@empty-why],
)


=== Émission de l'état <send-lowstate>

Avant de démarrer un nouveau pas de simulation, la méthode `::PreUpdate` vient mettre à jour l'état du robot simulé en modifiant le _State buffer_ interne au plugin (1A). Gazebo envoie également le nouveau tick de simulation (1C) et les valeurs du capteur IMU (1D) dans leurs topics respectifs.

Le `LowStateWriter` vient lire le _State buffer_ (1B) pour publier l'état sur le canal DDS (2, 3) qui est ensuite lu par $Pi$ (4), qui possède une subscription sur `rt/lowstate`, via sa propre utilisation du SDK d'Unitree.


#let transparent = luma(0).opacify(0%)

#architecture([Phase d'envoi de l'état], {
  edge(<preupdate>, "d", <statebuf.west>, "->", label-pos: 70%)[(1A): Joints]
  edge(
    <gz.west>,
    (-0.75, 1.5),
    (-0.75, 6),
    (2, 6),
    <gzimu>,
    "@..>",
    label-pos: 25%,
  )[(1D)]
  edge(
    <gz.east>,
    (0.5, 1.5),
    (0.5, 5),
    <gzclock.west>,
    "@..>",
    label-pos: 25%,
  )[(1C)]
  // edge(<gz>, "d,d,d,d,d,r", <gzclock>, "@..>", label-pos: 30%)[(1D)]
  // edge(<gz>, "d,d,d,d,d,r,r", <gzimu>, "@..>", label-pos: 30%)[(1C)]
  edge(<statebuf>, "@->", <lowstate>)[(1B)]
  edge(<lowstate>, "->", <publisher>)[(2)]
  edge(<publisher>, (1, 0), <channelfactory.west>, "->")[(3)]
  edge(
    <policy>,
    (0, 0),
    <channelfactory.west>,
    "<--@",
    label-pos: 20%,
  )[(4) subscription]
  edge(
    <gzclock>,
    "@->",
    <statebuf>,
    label-pos: 30%,
    label-side: right,
  )[(2C): Tick]
  edge(
    <gzimu.west>,
    (1.5, 5),
    (1.5, 3),
    <statebuf.east>,
    "->",
    label-pos: 40%,
  )[(2D): IMU]
  edge(
    <policy>,
    (0, 0),
    <channelfactory.west>,
    stroke: none,
    label-pos: 88%,
    label-side: left,
    label-fill: white,
  )[(4) publish]
})


Ici également, `LowStateWriter` s'exécute _parallèlement_ à `::PreUpdate`: En effet, on démarre une boucle qui vient exécuter `LowStateWriter` périodiquement, dans un autre _thread_: on a donc aucune garantie de synchronisation entre les deux.

Ici, il y a en plus non pas deux, mais _cinq_ boucles indépendantes qui sont en jeu:

- La boucle de simulation de Gazebo (fréquence d'appel de `::PreUpdate`),
- La boucle du `ChannelPublisher` (fréquence d'appel de `::LowStateWriter`), et
- La boucle de réception de $Pi$ (fréquence de réception de messages pour $Pi$)
- La boucle de mise à jour du tick (fréquence d'envoi de ticks de simulation par Gazebo)
- La boucle de mise à jour de l'IMU (fréquence d'envoi des valeurs du capteur IMU par Gazebo)


Similairement à la réception de commandes, en comparant à la boucle de mise à jour de $Pi$:

/ Si `::PreUpdate` est plus fréquente: On perdra des états intermédiaires, la résolution temporelle de l'évolution de l'état du robot disponible pour (ou acceptable par#footnote[
    En fonction de si `::LowStateWriter` est plus fréquente que $Pi$ (dans ce cas là, c'est ce qui est acceptable par $Pi$ qui est limitant) ou inversement (dans ce cas, c'est ce que la boucle du publisher met à disposition de $Pi$ qui est limitant)
  ]) $Pi$ sera moins grande
/ Si `::PreUpdate` est moins fréquente: $Pi$ reçevra plusieurs fois le même état, ce qui sera représentatif du fait que la simulation n'a pas encore avancé.


On a des effets similaires en comparant la fréquence de la boucle de mise à jour de l'IMU avec celle de la boucle de $Pi$:

/ Si la boucle IMU est plus fréquente: Certaines valeurs du capteur ne seront pas prises en compte par la politique
/ Si la boucle IMU est moins fréquente: $Pi$ recevra plusieurs fois le même état, ce qui sera représentatif du fait que la simulation n'a pas encore avancé.

Pour la boucle du tick, cela a peu d'importance. En effet, $Pi$ ne dépend probablement pas du tick de simulation, ou si elle en dépend, on suppose que c'est une dépendance à une valeur peu précise (ce serait plutôt pour savoir "depuis quand est-ce qu'on a lancé la politique", ce qui ne demande pas une précision à la milliseconde). On met quand même à jour le tick pour que nos messages `rt/lowstate` synthétiques se rapprochent le plus possible des vrais messages, tels qu'envoyés par le robot physique.

== Désynchronisations

Dans un même appel de `::PreUpdate`, on effectue d'abord la mise à jour du _State buffer_, puis on lit dans le _Commands buffer_.

Un cycle correspond donc à cinq boucles indépendantes, représentées ci-après:

/ Bleu: Simulation, qui doit englober l'entièreté d'un cycle
/ Rouge: `ChannelPublisher`
/ Rose: Politique $Pi$
/ Vert: Mise à jour de l'IMU
/ Orange: Mise à jour du tick de simulation

#architecture(
  [Cycle complet. Un cycle commence avec la flèche "update" partant de `::PreUpdate`],
  {
    let colored-edge = (color, label, ..args) => edge(
      stroke: color,
      label: text(fill: color, label),
      ..args,
    )
    let sim-edge = (..args) => colored-edge(blue, ..args)
    let publisher-edge = (..args) => colored-edge(red, ..args)
    let imu-edge = (..args) => colored-edge(olive.darken(30%), ..args)
    let clock-edge = (..args) => colored-edge(orange, ..args)
    let policy-edge = (..args) => colored-edge(fuchsia, ..args)

    // Simulation loop
    sim-edge("read", <preupdate>, "d,d,r,r", <cmdbuf>, "<-@")
    sim-edge(
      "update",
      <preupdate.east>,
      "d",
      <statebuf>,
      "->",
      label-pos: 70%,
      label-side: right,
    )

    // lowstate publisher loop
    publisher-edge("read", <statebuf>, "@->", <lowstate>)
    publisher-edge("", <lowstate>, "-", <publisher>)
    publisher-edge("", <publisher>, (1, 0), <channelfactory.west>, "->")

    // policy loop
    // dds part
    policy-edge(
      "commands",
      <policy>,
      (2.25, -1),
      (2.25, 0),
      <channelfactory.east>,
      "-->",
      label-pos: 10%,
    )
    policy-edge(
      "state",
      <policy>,
      (0, 0),
      <channelfactory.west>,
      "<--@",
      label-pos: 80%,
    )
    // non-dds part
    policy-edge("", <channelfactory.east>, (2, 0), <subscriber>, "->")
    policy-edge("", <subscriber>, "-", <lowcmd>)
    policy-edge("update", <lowcmd>, "->", <cmdbuf>)

    // imu loop
    imu-edge(
      "update",
      <gzimu>,
      (1.5, 5),
      (1.5, 3),
      <statebuf>,
      "->",
      label-pos: 45%,
    )
    for _ in range(2) {
      // XXX hack to increase thickness of dotted line
      imu-edge(
        "",
        <gz.west>,
        (-0.75, 1.5),
        (-0.75, 6),
        (2, 6),
        <gzimu>,
        "@..>",
        label-pos: 45%,
      )
    }

    // clock loop
    clock-edge(
      "update",
      <gzclock>,
      <statebuf>,
      "->",
      label-pos: 25%,
      label-side: right,
    )
    for _ in range(3) {
      // XXX hack to increase thickness of dotted line
      clock-edge(
        "",
        <gz.east>,
        (0.5, 1.5),
        (0.5, 5),
        <gzclock.west>,
        "@..>",
        label-pos: 45%,
      )
    }
  },
)

Ces désynchronisations pourraient expliquer les problèmes de performance recontrés (cf @perf)

== Vérification sur des politiques réelles

Après avoir testé le bridge sur les politiques d'examples fournies par Unitree, il a été testé sur une politique en cours de développement au sein de l'équipe de robotique du LAAS, Gepetto.

L'analyse de la vidéo (cf @video) montre que le bridge fonctionne: le comportement du robot est similaire à celui sur Isaac.

== Amélioration des performances <perf>

Les premiers essais affichent un facteur temps-réel#footnote[Appelé RTF (Real-Time Factor) @rtf. Un RTF de 100% signifie que la simulation s'exécute à vitesse réelle, un RTF inférieur à 1 signifie que la simulation est plus lente que ce qu'elle simule] autour des 10 à 15%.

#grid(
  columns: 2,
  gutter: 2em,
  [
    En utilisant le _profiler_ de Gazebo @gzprof, on peut capturer des intervalles de temps et les annoter, pour identifier ce qui ralenti les cycles de simulation.
  ],
  [
    ```cpp
    GZ_PROFILE_BEGIN("Label");
    ...
    GZ_PROFILE_END();
    ```

  ],
)

// On peut créer plusieurs segments en parallèle quand le programme possède plusieurs threads:
//
// ```cpp
// GZ_PROFILE_THREAD_NAME("Nom du thread");
// ```

#figure(
  caption: [Profilage de _gz-unitree_ lors d'une simulation],
  image("./profiler-many-ticks.png"),
)

Chaque groupe de segment correspond à un cycle de simulation.

Prenons un cycle en particulier:

#let durations = (0.267, 0.051, 0.039, 0.142, 0.028) // total, state, tick+crc, pub state, cmd
#let dur = idx => [#durations.at(idx) ms]
#figure(
  caption: [Profil d'un cycle de simulation],
  table(
    columns: durations.slice(1).map(x => x / durations.at(0) * 1fr),
    table.cell([`::PreUpdate` #dur(0)], colspan: 4),
    [Update state \ #dur(1)],
    [Tick+CRC \ #dur(2)],
    [Publish state \ #dur(3)],
    [Update cmd. \ #dur(4)]
  ),
)


Plus de la moitié du temps de calcul du plugin est dû à de l'envoi de l'état du robot sur le canal DDS `rt/lowstate`.

Notons également que, même si ce cyle-là a duré 0.267 ms, la durée d'un cycle est assez variable, certains atteignent 0.8 ms.

#image("./profiler-two-ticks.png")

Quelques mesures ont été tentées pour réduire le temps nécéssaire à l'envoi d'un message DDS:

/ Restreindre DDS à `localhost`: Il est possible que DDS envoie les messages en mode "broadcast", c'est-à-dire à tout addresse IP accessible dans un certain intervalle. En restreignant à `localhost`, on s'assure que le message n'a pas à être copié plusieurs fois.
/ Déplacer dans un autre thread: C'est ce qui a motivé la désynchronisation du thread "LowStateWriter" (cf @send-lowstate)
/ Ajuster la fréquence d'envoi: Une fois `LowStateWriter` déplacé dans un thread indépendant, on peut ajuster la fréquence d'envoi, le thread étant récurrant#footnote[Créé avec `CreateRecurrentThreadEx`]

Ainsi que d'autres optimisations, qui ne sont pas en rapport avec cette phase d'un cycle:

/ Mise en cache de joints à l'initialisation du plugin: pour éviter de devoir appeler `model.JointByName` dans une _hot loop_#footnote[Boucle (`for` ou `while`) dont le corps est exécuté un très grand nombre de fois, et dont la rapidité est importante].
/ Utilisation d'une implémentation de CRC32 plus rapide: tentative avec _CRC++_ @crcpp non achevée, à cause d'un _stack smashing_ pendant l'exécution


Après optimisations, on arrive à atteindre un RTF aux alentours des 30%. Des recherches supplémentaires sont nécéssaires pour atteindre un RTF raisonnable.

== Enregistrement automatique de vidéos <video>

Gazebo possède une fonctionnalité d'enregistrement vidéo, ce qui s'avère utile pour partager des résultats de simulation.

Cependant, l'enregistrement vidéo n'est pas nativement contrôlable programmatiquement. L'idée était en effet de faire automatiquement tourner une simulation à chaque changement de la politique RL, et d'obtenir la vidéo du résultat, pour en observer l'évolution.

Il a donc fallu développer un autre plugin, héritant de `gz::gui::Plugin` cette fois-ci. Ce plugin écoute des messages sur des topics Gazebo, `/gui/record_video/`${$`start`,`stop`$}$, et permet de démarrer et arrêter l'enregistrement, tout en indiquant le chemin vers le fichier MP4 de sortie.

Au final, un script complet permettant de démarrer une simulation et l'enregistrer en MP4 ressemble à ceci

```bash
# Fonction pour envoyer un message Gazebo avec un argument de type String et une valeur de retour de type Booléen
send_to_gz() {
  gz service -s $1 --reqtype gz.msgs.StringMsg --reptype gz.msgs.Boolean --req "data: \"$2\""
}

# Lancement en arrière plan
gz sim robot.sdf & sim_pid=$!
# On attends que la simulation soit prête
sleep 30

# Lancement de l'enregistrement
send_to_gz /gui/record_video/start mp4

# Lancement de la politique RL
uv run policy.py & policy_pid=$!
# On décide de la durée maximale de la vidéo (si la politique ne l'arrête pas d'elle même)
sleep 120
kill $policy_pid

# Arrêt de l'enregistrement
send_to_gz /gui/record_video/stop file:///tmp/result.mp4

# Arrêt du simulateur
kill $sim_pid

# La vidéo est disponible à /tmp/result.mp4
```

== Mise en CI/CD


On appelle CI/CD (pour _Continuous Integration / Continuous Delivery_) la pratique consistant à intégrer fréquemment des petits changements à un dépôt de code source commun, en lançant des tests régulièrement (partie "CI") et éventuellement en déployant la base de code fréquemment (partie "CD") @cicd.

Une fois l'enregistrement vidéo rendu automatisable, si l'on veut mettre en place l'enregistrement vidéo automatique à chaque changement de la politique, il faut crééer une description de _workflow_ (dans notre cas, un workflow _Github Actions_).

Un workflow est un ensemble de commandes à exécuter dans un environnement virtualisé#footnote[Qu'il s'agisse d'une machine virtuelle ou d'un simple container] ainsi que des évènements et conditions décrivant quand lancer l'exécution (par exemple, "à chaque commit sur la branche `main`"). C'est un des outils permettant de mettre en place la CI/CD.

=== Une image de base avec Docker

L'environnement d'exécution des workflows ne comporte pas d'installation de Gazebo. Étant donné le temps de compilation élevé, on peut "factoriser" cette étape dans une _image de base_, de laquelle on démarre pour chaque exécution du workflow, dans laquelle tout les programmes nécéssaires sont déjà installés.

Pour cela, on part d'une image Ubuntu, dans lequelle on installe le nécéssaire: Just (pour lancer des commandes, un sorte de Makefile mais plus moderne @just), FFMpeg (pour l'encodage H.264 servant à la création du fichier vidéo), XVFB (pour émuler un serveur X, cf @simulate-x), Python (pour lancer la politique RL), Gazebo et gz-unitree.

```dockerfile
FROM ubuntu:24.04

RUN apt update
# Just
RUN apt install -y curl just sudo
# Python (via le gestionnaire de versions et dépendances UV)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Code source de gz-unitree
COPY . .

# Gazebo et outils de compilation
RUN just setup

# FFMpeg, XVFB
RUN apt install -y git ffmpeg xvfb xterm


# Compilation et installation de de gz-unitree
RUN mkdir -p /usr/local/lib/gz-unitree/
RUN just install
```

Un autre workflow, défini cette fois-ci dans le dépôt de gz-unitree et non celui de la politique RL, crée une image Docker depuis ce Dockerfile, qui est ensuite utilisable via `ghcr.io/Gepetto/gz-unitree` @gzu-ghcr. Les commandes installant Gazebo et les outils de compilation sont écrites dans le _Justfile_, que nous lançons ici avec `RUN just setup`.

=== Une pipeline Github Actions

Une fois cette image disponible, on peut l'utiliser dans un workflow Github sur le dépôt Git de la politique RL:

#zebraw(
  numbering: false,
  highlight-lines: (6, 7),
  ```yaml
  jobs:
    test:
      runs-on: ubuntu-latest
      container:
        image: ghcr.io/gepetto/gz-unitree:latest
      steps:
        - name: Checkout repository
          uses: actions/checkout@v5
  ```,
)

Et lancer la simulation et l'enregistrement vidéo.

Pour récupérer le fichier vidéo final, on peut utiliser la notion d'_artifacts_ de Github Actions:

```yaml
       - name: Save video as artifact
         uses: actions/upload-artifact@v4
         with:
           name: gz-unitree-video
           path: /tmp/result.mp4
```

#v(0.5em)
#grid(
  columns: (5fr, 3fr),
  gutter: 2em,
  [

    ==== Un environnement de développement contraignant
    Développer et débugger une définition de workflow peut s'avérer complexe et particulièrement chronophage: n'ayant pas d'accès interactif au serveur exécutant celui-ci, il faut envoyer ses changements au dépôt git, attendre que le workflow s'exécute entièrement, et regarde si quelque chose s'est mal passé.

    Par exemple, si jamais des fichiers sont manquants, ou ne sont pas au chemin attendu, il faut modifier le workflow pour y rajouter des instruction listant le contenu d'un répertoire (en utilisant `ls` ou `tree`, par exemple), lancer le workflow à nouveau et regarder les logs.

    Ceci rend le développement assez fastidieux, surtout quand le workflow s'exécute pendant des dizaines de minutes.

    ==== Émuler un serveur graphique <simulate-x>

    Les environnements de CI/CD s'apparentent plus à des serveurs qu'à des ordinateurs complets: en particulier, il n'y a pas d'interface graphique et donc pas de serveur d'affichage (_display server_).

    Mais Gazebo a besoin d'un display server pour enregistrer une vidéo.

    Il faut donc simuler un serveur d'affichage. Dans notre cas, l'environnement de CI/CD étant sous Linux, on simule un serveur X11 avec _XVFB_ @xvfb.

  ],
  figure(
    caption: [Quelques commits liés au développement du workflow#footnote[Les émojis servent d'icônes pour différencier les types de commits, via le standard Gitmoji @gitmoji]],
    trimmed-image("./cicd-commits.png", trim: (right: 65%)),
  ),
)

