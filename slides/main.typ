#import "../rapport/utils.typ": dontbreak, todo
#import "../rapport/context.typ": argmax, cL, definitions_paths_set, exp
#import "../rapport/gz-unitree.typ": overlayed-img, zebraw
#import "@preview/touying:0.6.1": *
#import themes.simple: *

#import "@preview/fletcher:0.5.8": edge, node
#import "@preview/fletcher:0.5.8"
#import "@preview/diagraph:0.3.6"

#show figure: set block(spacing: 4em)
#let diagram = (caption: none, ..args) => figure(
  caption: caption,
  touying-reducer.with(reduce: fletcher.diagram, cover: fletcher.hide)(..args),
)

#let centered = content => {
  v(1fr)
  align(center, content)
  v(1fr)
}

#show: simple-theme.with(aspect-ratio: "16-9")
#set text(font: "New Computer Modern")
#show raw: set text(font: "Martian Mono", size: 0.8em)

= _gz-unitree_: Reinforcement learning en robotique avec validation par moteurs de physique multiples pour le robot _H1v2_ d'Unitree

Gwenn Le Bihan `<gwenn.lebihan@etu.inp-n7.fr>` \
#datetime.today().display("[day padding:none] Novembre [year]") \

#title-slide[
  == Reinforcement Learning

  Et son application à la robotique
]


== Bases du RL

#diagram(
  node((0, 0))[Agent],
  node((1, 0))[Environnement],
  node((2, 0))[Score],

  pause,
  edge((0, 0), (1, 0), "->")[Action],

  pause,
  edge((1, 0), (2, 0), "-->")[Fonction coût],

  pause,
  edge((2, 0), (0, 0), "->", bend: 45deg)[Mise à jour],
)

== RL en robotique

#diagram(
  node((0, 0), todo[Photo H1v2]),
  node((1, 0), todo[H1v2 dans gz]),
  node((2, 0))[Score],
  edge((0, 0), (1, 0), "->")[genou gauche +0.5°],
  edge((1, 0), (2, 0), "-->", $cal(L)$),
  edge((2, 0), (0, 0), "->", bend: 45deg)[Mise à jour],
)



== C'est quoi $cal(L)$ ?

#centered[

  C'est très simple:

  $
    cal(L)_r (pi', pi) := exp_((s_t, a_t)_(t in NN) in cal(C)) sum_(t=0)^oo (Q_pi (s_t, a_t)) / (Q_pi' (s_t, a_t)) A_(pi, r)(s_t, a_t)
  $

]


#title-slide[

  == Comparaison des politiques

  En Reinforcement Learning

]

#let loop = (pauses: false) => diagram(
  node((0, 0), $s_t$),
  if pauses { pause } else { none },
  if pauses {
    edge(corner: right, label-pos: 2 / 8, label-side: left)[choix de l'action]
  } else { none },
  edge("->", corner: right, label-pos: 3 / 8, label-side: left)[$Pi$],
  node((1, -1))[$a_t$],
  if pauses { pause } else { none },
  edge("->", corner: right, label-pos: 5 / 8, label-side: left)[$M$],
  if pauses {
    edge(corner: right, label-pos: 6 / 8, label-side: left)[simulation]
  } else { none },
  node((2, 0))[$s_(t+1)$],
  if pauses { pause } else { none },
  edge((2, 0), (2, .75), (0, .75), (0, 0), "-->", label-side: left)[itération],
)

#centered(loop(pauses: true))
#pagebreak()


#centered[
  #grid(
    columns: 2,
    gutter: 3em,

    loop(pauses: false),

    [
      #diagram(
        $
          s_0 edge(a_0, ->) & s_1 edge(a_1, ->) & s_2 edge(a_2, ->) & dots.c
        $,
      )

      #pause

      $
        ((s_0, a_0), (s_1, a_1), (s_2, a_2), ...)
        pause
        in cal(C)
      $

    ],
  )
]

#pagebreak()

#centered[
  $
                         A & := "actions possibles" \
                         S & := "états possibles" \
    #definitions_paths_set
  $
]

#pagebreak()

== Comparaison des politiques: Avantage $A$

#centered[
  À quel point est-il mieux de choisir $a_t$ plutôt qu'une autre action?
]

#pagebreak()

#centered[


  #let height = 2
  #scale(70%, reflow: true, diagram((
    // Prior path
    node((0, 0))[$dots.c$],
    edge("->")[$a_(t-2)$],
    node((1, 0))[$s_(t-1)$],
    edge("->")[$a_(t-1)$],
    pause,
    node((2, 0), name: <break>)[$s_t$],
    edge("-")[],
    node((3.5, 0)),
    edge("->", label-pos: 0%)[$a_t$],
    node((4.5, 0))[$sum_(i=t+1)^oo gamma^t r(s_i)$],
    node(name: <bottom>, (4.5, +1.5))[$sum_(i=t+1)^oo gamma^t r(s'_i)$ ],
    node(name: <top>, (4.5, -1.5))[$sum_(i=t+1)^oo gamma^t r(s''_i)$],
    edge(<break>, <bottom>, "->", bend: -25deg)[$a'_t$],
    edge(<break>, <top>, "->", bend: 25deg)[$a''_t$],
    pause,
    // Expectation bar V(s)
    node((5, height)),
    edge("--"),
    node((1.85, height)),
    edge("-", label-side: left, label-pos: 75%)[$exp$],
    node((1.85, -height)),
    edge("--")[],
    node((5, -height)),
    // Expectation bar Q(s, a)
    node((5, 0.5)),
    edge("--"),
    node((3.25, 0.5)),
    edge("-", label-side: left, label-pos: 75%)[$exp$],
    node((3.25, -0.5)),
    edge("--")[],
    node((5, -0.5)),
  )))

  #pause

  $
    A_(pi, r)(s, a) := exp("avec" a_t) - exp("à" thick t-1)
  $

]

#pagebreak()


== C'est quoi $cal(L)$ ?

#centered[

  $
    cal(L)_r (pi', pi) := pause exp_((s_t, a_t)_(t in NN) in cal(C)) pause sum_(t=0)^oo pause (Q_pi (s_t, a_t)) / (Q_pi' (s_t, a_t)) A_(pi, r)(s_t, a_t)
  $

]

== Mise à jour de $Pi$

#centered[

  $
    Pi' = & cases(
              argmax_(pi) cL_r (pi, Pi),
              "s.c.  distance"(Pi', Pi) < delta
            )
  $

]

== Mise à jour de $Pi$: distance entre politiques

#centered[
  $
    "distance"(Pi', Pi) & := max_(s in S) D_"KL" (Q_Pi' (s, dot) || Q_Pi (s, dot)) \
       D_"KL" (P || P') & := sum_(x in cal(X)) P(x) log P(x) / (P'(x))
  $
]


#title-slide[
  == Le _SDK_#super[1] d'Unitree
  #super[1]Software Development Kit
]



== Le SDK d'Unitree

#centered[
  #diagram((
    node((0, 0), $Pi$),
    node((1, 0), "SDK"),
    node((2, 0), "robot"),
    edge((0, 0), (0, 0), "<-", bend: 130deg, loop-angle: 180deg)[],
    edge((2.25, 0), (2.25, 0), "->", bend: -130deg, loop-angle: -180deg)[],
    edge((0, 0), (1, 0), "->", shift: 7pt)[ordres],
    edge((0, 0), (1, 0), "<-", shift: -7pt, label-side: right)[état],
    edge((1, 0), (2, 0), "-->", shift: 7pt)[ordres],
    edge((1, 0), (2, 0), "<--", shift: -7pt, label-side: right)[état],
  ))

  #diagram((
    edge((0, 0), (1, 0), "-->"),
    node((1.40, 0))[Message DDS],
  ))
]


== Le SDK d'Unitree

#centered[
  #diagram({
    node((0, 0), $Pi$)
    node((1, 0), "SDK")
    node((2, 0))[*Bridge*]
    node((3, 0), "Simulateur")

    edge((0, 0), (0, 0), "<-", bend: 130deg, loop-angle: 180deg)[]
    edge((3.25, 0), (3.25, 0), "->", bend: -130deg, loop-angle: -180deg)[]

    for i in range(0, 3) {
      let dash = if i == 1 { "--" } else { "-" }
      edge((i, 0), (i + 1, 0), dash + ">", shift: 7pt)[ordres]
      edge((i, 0), (i + 1, 0), "<" + dash, shift: -7pt, label-side: right)[état]
    }

    edge((0, 1), (2, 1), "|-|", label-side: right)[API du SDK]
    edge((2, 1), (3, 1), "|-|", label-side: right)[API du simulateur]
  })
]


== `unitree_mujoco`

#centered(scale(70%, reflow: true, diagram({
  node(name: <sdk>, (0, 0))[SDK]
  node(enclose: ((1, 1), (-1, 1)), stroke: blue, inset: 10pt, snap: false, text(fill: blue)[Canaux \ DDS])
  node(name: <lowcmd>, (1, 1))[`rt/lowcmd`]
  node(name: <lowstate>, (-1, 1))[`rt/lowstate`]
  node(name: <bridge>, enclose: ((1, 2), (-1, 2)), stroke: black, inset: 10pt)[Bridge]
  node(name: <mujoco>, (0, 3))[Mujoco]


  edge(<sdk>, <lowcmd>, "->", bend: 30deg)[pub]
  edge(<lowcmd>, (1, 2), "-->", bend: 20deg)[via sub]
  edge((1, 2), <mujoco>, "->", bend: 20deg, `data->ctrl[i] = ...`)

  edge(<sdk>, <lowstate>, "<--", bend: -30deg)[via sub]
  edge(<lowstate>, (-1, 2), "<-", bend: -20deg)[pub]
  edge((-1, 2), <mujoco>, "<-", bend: -20deg, `... = data->sensordata[i]`)

  edge(<mujoco>, <mujoco>, "->", bend: 130deg, loop-angle: -90deg, `mj_step(model, data)`)
})))


#title-slide[
  == Développement de _gz-unitree_
  Un bridge pour Gazebo
]

#centered[
  #diagram({
    node((0, 0), $Pi$)
    node((1, 0), "SDK")
    node((2, 0))[*gz-unitree*]
    node((3, 0), "Gazebo")

    edge((0, 0), (0, 0), "<-", bend: 130deg, loop-angle: 180deg)[]
    edge((3.25, 0), (3.25, 0), "->", bend: -130deg, loop-angle: -180deg)[]

    for i in range(0, 3) {
      let dash = if i == 1 { "--" } else { "-" }
      edge((i, 0), (i + 1, 0), dash + ">", shift: 7pt)[ordres]
      edge((i, 0), (i + 1, 0), "<" + dash, shift: -7pt, label-side: right)[état]
    }

    edge((0, 1), (2, 1), "|-|", label-side: right)[API du SDK]
    edge((2, 1), (3, 1), "|-|", label-side: right)[API de Gazebo]
  })
]

#pagebreak()

#centered(scale(75%, reflow: true, ```cpp
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
```))

#pagebreak()

#centered(scale(75%, reflow: true, grid(
  columns: 2,
  gutter: 2em,
  ```cpp
  #include <gz/plugin/Register.hh>

  ... // class implementation

  GZ_ADD_PLUGIN(
      UnitreePlugin,
      gz::sim::System,
      UnitreePlugin::ISystemPreUpdate)
  ```,

  zebraw(
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
  ),
)))

#pagebreak()


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
) => {
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
      dy: 3.5 * group-inset * if alignment.y == bottom { 1 } else { -1 },
      text(fill: group-color, label),
    )),
  )

  let subtitled = (title, subtitle) => [#title \ #text(
      size: 0.8em,
      subtitle,
    )]

  diagram(
    debug: false,
    node-stroke: 0.5pt,
    edge-corner-radius: 6pt,
    (
      node(name: <configure>, (0, 1), `::Configure`),
      node(name: <preupdate>, (0, 2), `::PreUpdate`),
      group(
        name: <gz>,
        (<configure>, <preupdate>),
        `gz::sim::System`,
        alignment: top + center,
      ),
      node(
        name: <channelfactory>,
        enclose: ((1, 0), (2, 0)),
        inset: 8pt,
        subtitled(`ChannelFactory`, [domaine 1, interface `lo`]),
      ),
      node(name: <publisher>, (1, 1), inset: 8pt, subtitled(
        `ChannelPublisher`,
        [canal `rt/lowstate`],
      )),
      node(name: <subscriber>, (2, 1), inset: 8pt, subtitled(
        `ChannelSubscriber`,
        [canal `rt/lowcmd`],
      )),
      group(
        name: <dds>,
        (<channelfactory>, <publisher>, <subscriber>),
        alignment: top + center,
      )[Unitree SDK],
      node(name: <gzclock>, (1, 5), subtitled(
        `::TickHandler`,
        [topic Gazebo `/clock`],
      )),
      node(name: <gzimu>, (2, 5), subtitled(
        `::IMUHandler`,
        [topic Gazebo `/imu`],
      )),
      node(name: <lowstate>, (1, 2), `::LowStateWriter`),
      node(name: <lowcmd>, (2, 2), `::CmdHandler`),
      node(name: <statebuf>, (1, 3), subtitled("State buffer", `statebuf`)),
      node(name: <cmdbuf>, (2, 3), subtitled("Commands buffer", `cmdbuf`)),
      group(
        (
          <lowstate>,
          <lowcmd>,
          <statebuf>,
          <cmdbuf>,
          <gzclock>,
          <gzimu>,
        ),
        [Plugin internals],
      ),
      node(name: <policy>, (0, -1), $Pi$),
      ..edges.pos(),
      if show-legend {
        node((0, 5), stroke: none, width: 15em, fill: white, legend(
          ("-->", "Message DDS"),
          ("..>", "Message Gazebo"),
          ("@->", "Désynchronisation"),
        ))
      },
    ),
  )
}

#centered-slide(scale(56%, reflow: true, architecture([Phase d'initialisation du plugin], show-legend: false, (
  edge(
    <configure>,
    "u",
    <channelfactory>,
    "->",
    label-side: left,
    label-pos: 50%,
  )[appelle],
  pause,
  edge(<configure>, "d,d,d,r", <gzclock>, "->", label-pos: 85%)[démarre],
  edge(

    <configure>,
    "d,d",
    (0, 3.75),
    "r,r",
    <gzimu>,
    "->",
    label-pos: 75%,
  )[démarre],
  pause,
  edge(<channelfactory>, "->", <publisher>)[initialise],
  edge(<channelfactory>, "->", <subscriber>)[initialise],
  pause,
  edge(<publisher>, "<->", <lowstate>)[`std::bind`],
  edge(<subscriber>, "<->", <lowcmd>)[`std::bind`],
))))
