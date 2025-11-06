#import "../rapport/utils.typ": dontbreak, todo
#import "../rapport/context.typ": definitions_paths_set, exp
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
    cal(L)_r (pi', pi) := pause exp_((s_t, a_t)_(t in NN) in cal(C)) pause sum_(t=0)^oo pause (Q_pi (s_t, a_t)) / (Q_pi' (s_t, a_t)) pause A_(pi, r)(s_t, a_t)
  $

]

#title-slide[
  == Optimisation de $Pi$
  Mise à jour de la politique RL
]

