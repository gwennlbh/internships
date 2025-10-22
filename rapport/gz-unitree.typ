#import "@preview/zebraw:0.5.5"
#import "@preview/fletcher:0.5.8": diagram, node, edge
#import "./utils.typ": dontbreak
#show figure: set block(spacing: 2em)
#let zebraw = (..args) => zebraw.zebraw(lang: false, background-color: luma(255).opacify(0%), ..args)

En se basant sur _unitree\_mujoco_, il a donc été possible de réaliser un bridge pour Gazebo.

== Établissement du contact

Une première tentative a été de suivre la documentation de CycloneDDS pour écouter sur le canal @cyclonedds-helloworld `rt/lowcmd`, en récupérant les définitions IDL des messages, disponibles sur le dépot `unitree_ros2`#footnote[`unitree_mujoco` n'avait pas encore été découvert] @unitree_ros2

On commence par importer la bibliothèque DDS et les définitions IDL de `rt/lowcmd`

```cpp
#include "messages/LowCmd_.hpp"
#include "dds/dds.h"
...

int main (int argc, char ** argv)
{
```

On initialise les différents objets permettant de lire sur un canal

```cpp
  dds_entity_t participant, topic, reader;
  LowCmd_ *msg;
  void *samples[MAX_SAMPLES];
  ...

  participant = dds_create_participant(DDS_DOMAIN_DEFAULT, NULL, NULL);

  topic = dds_create_topic(participant, &LowCmd__desc, "HelloWorldData_Msg", NULL, NULL);

  qos = dds_create_qos();
  dds_qset_reliability(qos, DDS_RELIABILITY_RELIABLE, DDS_SECS (10));

  reader = dds_create_reader(participant, topic, qos, NULL);

  dds_delete_qos(qos);

  samples[0] = LowCmd___alloc();
```

Et on attend qu'un message arrive sur le canal, pour l'afficher

```cpp
  /* Poll until data has been read. */
  while (true)
  {
    rc = dds_read(reader, samples, infos, MAX_SAMPLES, MAX_SAMPLES);

    /* Check if we read some data and it is valid. */
    if ((rc > 0) && (infos[0].valid_data))
    {
      /* Print Message. */
      msg = (LowCmd_*) samples[0];
      printf("=== [Subscriber] Received : ");
      fflush(stdout);
      break;
    }
    else
    {
      dds_sleepfor(DDS_MSECS(20));
    }
  }
```

Enfin, on libère les ressources avant la terminaison du programme

```cpp
  LowCmd__free(samples[0], DDS_FREE_ALL);
  dds_delete(participant);
  return EXIT_SUCCESS;
}
```

Malheureusement, cette solution s'est avérée infructueuse, à cause de (ce qui sera compris bien plus tard) un problème de numéro de domaine DDS.

On change d'approche en préférant plutôt utiliser les abstractions fournies par le SDK de Unitree (cf @receive-lowcmd et @send-lowstate)


Enfin, si un pare-feu est actif, il faut autoriser le traffic udp l'intervalle d'addresses IP `224.0.0.0/4`. Par exemple, avec _ufw_

```bash
sudo ufw allow in proto udp from 224.0.0.0/4
sudo ufw allow in proto udp to 224.0.0.0/4
```



== Installation du plugin dans Gazebo

Un _system plugin_ Gazebo consiste en la définition d'une classe héritant de `gz::sim::System`, ainsi que d'autres interfaces permettant notamment d'exécuter notre code avant ou après une mise à jour de l'état du simulateur (avec `gz::sim::ISystem`{`Pre`,`Post`}`Update`)

#dontbreak(

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
                       gz::sim::EntityComponentManager &_ecm) override;
    };
}
```

)

Il faut ensuite implémenter la classe puis appeler une macro ajoutant le plugin à Gazebo

```cpp
#include <gz/plugin/Register.hh>

... // implementation

GZ_ADD_PLUGIN(
    UnitreePlugin,
    gz::sim::System,
    UnitreePlugin::ISystemPreUpdate)
```

Enfin, on active le plugin en le référançant dans le fichier SDF @sdf-plugin, qui décrit l'environnement du simulateurs (objets, éclairage, etc)

#zebraw(
  numbering: false,
  highlight-lines: (..range(3, 5)),
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
  ```
)

Avec `filename` le chemin vers le plugin compilé, qui sera cherché dans les répertoires spécifiés par `GZ_SIM_SYSTEM_PLUGIN_PATH` @gz-system-plugin-path @sdf-plugin-filename.


== Architecture du plugin

Le plugin consiste en trois parties distinctes:

1. Le "branchement" dans les phases de Gazebo, par l'implémentation de méthodes de `gz::sim::System`
2. L'interaction avec les canaux DDS du SDK d'Unitree
3. Les données et méthodes internes au plugin

En plus de cela, il y a bien évidemment la politique de contrôle $cal(P)$, qui interagit via les canaux DDS avec le robot (qu'il soit réel, ou simulé)

#let legend = (
  ..descriptions
) => grid(
  columns: (1fr, 3fr), 
  align: left,
  row-gutter: 0.5em,
  ..descriptions.pos().map(((arrow, desc)) => (
    diagram(edge((0, 0), arrow, (0.75, 0))), 
    desc
  )).flatten()
)

#let architecture = (
  caption, 
  group-inset: 12pt, 
  group-color: luma(80), 
  show-legend: true,
  ..edges
) => figure(caption: caption,
  pad(
    y: 10pt + group-inset, 
  diagram(
    debug: false, 
    node-stroke: 0.5pt, 
    edge-corner-radius: 6pt,
  {

    if show-legend {
      node((2, 4.5), stroke: none, width: 15em, legend(("--", "Message DDS"), ("@->", "Désynchronisation")))
    }

    let group = (nodes, label, alignment: bottom + center, name: none) => node(
      name: name,
      enclose: nodes,
      snap: false,
      inset: group-inset,
      stroke: group-color.lighten(75%) + 2pt,
      align(alignment, move(dy: 2 * group-inset * if alignment.y == bottom { 1 } else { -1 }, text(fill: group-color, label)))
    )

    let subtitled = (title, subtitle) => [#title \ #text(size: 0.8em, subtitle)]

    node(name: <configure>, (0, 1), `::Configure`) 
    node(name: <preupdate>, (0, 2), `::PreUpdate`)
    group((<configure>, <preupdate>), `gz::sim::System`, alignment: top + center)

    node(name: <channelfactory>, enclose: ((1, 0), (2, 0)), inset: 8pt, subtitled(`ChannelFactory`, [domaine 1, interface `lo`]))
    node(name: <publisher>, (1, 1), inset: 8pt, subtitled(`ChannelPublisher` , [canal `rt/lowstate`]))
    node(name: <subscriber>, (2, 1), inset: 8pt, subtitled(`ChannelSubscriber` , [canal `rt/lowcmd`]))
    group(name: <dds>, (<channelfactory>, <publisher>, <subscriber>), alignment: top+center)[SDK d'Unitree]


    node(name: <lowstate>, (1, 2), `::LowStateWriter`)
    node(name: <lowcmd>, (2, 2), `::CmdHandler`)
    node(name: <statebuf>, (1, 3))[State buffer]
    node(name: <cmdbuf>, (2, 3))[Commands buffer]
    group((<lowstate>, <lowcmd>, <statebuf>, <cmdbuf>))[Plugin internals]

    node(name: <policy>, (0, -1), $cal(P)$)

    for e in edges.pos() {
      e
    }
  }
)))

#architecture([Phase d'initialisation du plugin], show-legend: false, {
  edge(<configure>, "u", <channelfactory>, "->", label-side: left, label-pos: 50%)[appelle]
  edge(<channelfactory>, "->", <publisher>)[initialise]
  edge(<channelfactory>, "->", <subscriber>)[initialise]
  edge(<publisher>, "<->", <lowstate>)[associés]
  edge(<subscriber>, "<->", <lowcmd>)[associés]
})

On commence par instancier un contrôleur dans le domaine DDS n°1, sur l'interface réseau `lo`#footnote[interface dite "loopback", qui est locale à l'ordinateur: ici, le simulateur et la politique de contrôle tournent sur la même machine, donc les messages DDS n'ont pas besoin de "sortir" de celle-ci]

On lui associe:

- Un _publisher_, chargé d'envoyer périodiquement des messages sur `rt/lowstate` en appellant la méthode `LowStateWriter`
- Un _subscriber_, chargé d'appeller la méthode `CmdHandler` avec chaque message arrivant sur `rt/lowcmd`.

Cette initialisation est faite à l'initialisation du plugin par Gazebo, en la faisant dans la méhode `::Configure` du plugin.

== Réception des commandes <receive-lowcmd>

Lorsqu'un message, publié par $cal(P)$ (1A) et contenant des ordres pour les moteurs, arrive sur `rt/lowcmd`, `::CmdHandler` est appelé (2, 3), et modifie un _buffer_ (4) contenant la dernière commande reçue.


Ensuite, Gazebo démarre un nouveau pas de simulation. Avant de faire ce pas, il appelle la méthode `::PreUpdate` sur notre plugin, qui vient chercher la commande stockée dans le _buffer_ (1B), et applique cette commande sur le modèle du robot, animé par le simulateur.

#architecture([Phase de réception des commandes], {
  edge(<policy>, (2, -1), (2, 0), "-->", label-pos: 10%)[(1A) publish]
  edge(<policy>, (2, -1), (2, 0), stroke: none, label-pos: 60%, label-side: left)[(1A) subscription]
  edge((2, 0), <subscriber>, "->")[(2)]
  edge(<subscriber>, "->", <lowcmd>)[(3)]
  edge(<lowcmd>, "->", <cmdbuf>)[(4)]
  // edge(<lowcmd.east>, "r,d,d,l,l,l,l,l,l,u,u,u", <preupdate>, "->", label-side: left)[(5)]
  edge(<preupdate>, "d,d,r,r", <cmdbuf>, "<-@")[(1B)]
})

On notera que (1B) s'exécute _parallèlement_ au reste des étapes: la boucle de simulation de Gazebo est indépendante de la boucle de mise à jour de la politique.


/ Si `::PreUpdate` est plus fréquente: Le simulateur appliquera simplement plusieurs fois la même commande, le buffer n'ayant pas été modifié.

/ Si `::PreUpdate` est moins fréquente: Certaines commandes seront simplement ignorées par Gazebo, qui ne vera pas la valeur du buffer avant qu'il change de nouveau.

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


== Émission de l'état <send-lowstate>

Avant de démarrer un nouveau pas de simulation, la méthode `::PreUpdate` vient mettre à jour l'état du robot simulé en modifiant le _State buffer_ interne au plugin (1A).

Le `LowStateWriter` vient lire le _State buffer_ (1B) pour publier l'état sur le canal DDS (2, 3) qui est ensuite lu par $cal(P)$ (4), qui (on le suppose) poss-de une subscription sur `rt/lowstate`

#let transparent = luma(0).opacify(0%)


#architecture([Phase d'envoi de l'état], {
  edge(<preupdate>, "d,d,r", <statebuf>, "->")[(1A)]
  edge(<statebuf>, "@->", <lowstate>)[(1B)]
  edge(<lowstate>, "->", <publisher>)[(2)]
  edge(<publisher>, "->", (1, 0))[(3)]
  edge(<policy>, (1, -1), (1, 0), "<--", label-pos: 20%)[(4) subscription]
  edge(<policy>, (1, -1), (1, 0), stroke: none, label-pos: 60%, label-side: left)[(4) publish]
})


Ici également, `LowStateWriter` s'exécute _en parallèle_ du code de `::PreUpdate`: En effet, la création du `ChannelPublisher` démarre une boucle qui vient éxécuter `LowStateWriter` périodiquement, dans un autre _thread_: on a donc aucune garantie de synchronisation entre les deux. 

Ici, il y a en plus non pas deux, mais _trois_ boucles indépendantes qui sont en jeux:

- La boucle de simulation de Gazebo (fréquence d'appel de `::PreUpdate`),
- La boucle du `ChannelPublisher` (fréquence d'appel de `::LowStateWriter`), et
- La boucle de réception de $cal(P)$ (à quelle fréquence $cal(P)$ est-elle capable de reçevoir des messages)


Similairement à la réception de commandes:

/ Si `::PreUpdate` est plus fréquente: On perdra des états intermédiaires, la résolution temporelle de l'évolution de l'état du robot disponible pour (ou acceptable par#footnote[
  En fonction de si `::LowStateWriter` est plus fréquente que $cal(P)$ (dans ce cas là, c'est ce qui est acceptable par $cal(P)$ qui est limitant) ou inversement (dans ce cas, c'est ce que la boucle du publisher met à disposition de $cal(P)$ qui est limitant)
]) $cal(P)$ sera moins grande
/ Si `::PreUpdate` est moins fréquente: $cal(P)$ reçevra plusieurs fois le même état, ce qui sera représentatif du fait que la simulation n'a pas encore avancé.

== Désynchronisations

Dans un même appel de `::PreUpdate`, on effectue d'abord la mise à jour du _State buffer_, puis on lit dans le _Commands buffer_. 

Un cycle correspond donc à trois boucles indépendantes, représentées ci-après: 

- Celle de la simulation (en bleu), qui doit englober l'entièreté d'un cycle
- Celle du `ChannelPublisher` (en rouge)
- Celle de $cal(P)$ (en rose)

#architecture([Cycle complet. Un cycle commence avec la flèche "update" partant de `::PreUpdate`], {
  let colored-edge = (color, label, ..args) => edge(stroke: color, label: text(fill: color, label), ..args)
  let sim-edge = (label, ..args) => colored-edge(blue, label, ..args)
  let publisher-edge = (label, ..args) => colored-edge(red, label, ..args)
  let policy-edge = (label, ..args) => colored-edge(fuchsia, label, ..args)

  // Simulation loop
  sim-edge("read",  <preupdate>, "d,d,r,r", <cmdbuf>, "<-@")
  sim-edge("update", <preupdate.east>, "d", <statebuf>, "->", label-pos: 70%, label-side: right)

  // lowstate publisher loop
  publisher-edge("read", <statebuf>, "@->", <lowstate>)
  publisher-edge("", <lowstate>, "-", <publisher>)
  publisher-edge("", <publisher>, (1, 0), <channelfactory.west>, "->")

  // policy loop
  // dds part
  policy-edge("commands", <policy>, (2.25, -1), (2.25, 0), <channelfactory.east>, "-->", label-pos: 10%)
  policy-edge("state", <policy>, (0, 0), <channelfactory.west>, "<--@", label-pos: 80%)
  // non-dds part
  policy-edge("", <channelfactory.east>, (2, 0), <subscriber>,  "->")
  policy-edge("", <subscriber>, "-", <lowcmd>)
  policy-edge("update", <lowcmd>, "->", <cmdbuf>)
})

Ces désynchronisations pourraient expliquer les problèmes de performance recontrés (cf @perf)

== Essai sur des politiques réelles

== Amélioration des performances <perf>

== Enregistrement de vidéos

=== Contrôle programmatique de l'enregistrement

== Mise en CI/CD

=== Une image de base avec Docker

=== Une pipeline Github Actions
