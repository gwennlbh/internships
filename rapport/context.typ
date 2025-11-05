#import "utils.typ": comment, refneeded, todo
#import "@preview/fletcher:0.5.8": edge, node
#import "@preview/fletcher:0.5.8"
#import "@preview/diagraph:0.3.6"

#show figure: set block(spacing: 4em)
#let diagram = (caption: none, ..args) => figure(
  caption: caption,
  fletcher.diagram(..args),
)
#let dontbreak = content => block(breakable: false, content)

#show math.equation.where(block: true): set block(spacing: 2em)

//#let prod = $op(Pi, limits: #true)$
#let card = $op("card")$
#let indicatrix = contents => $thin op(bb(1), limits: #true)_(#contents) thin$
#let argmax = $op("arg" #h(1em / 12) "max", limits: #true)$
#let exp = $op(bb(E), limits: #true)$
#let function = (name, input_domain, output_domain, args, body) => {
  $#name : thick thick cases(delim: #none, #input_domain &-> #output_domain, #args &|-> #body)$
}


== Bases théoriques du _Reinforcement Learning_

L'apprentissage par renforcement, ou _Reinforcement Learning_, permet de développer des programmes sans expliciter leur logique: on décrit plutôt quatre choses, qui vont permettre à la logique d'émerger pendant la phase d'entraînement:

- Un _agent_: c'est le programme que l'on souhaite créer
- Des _actions_ que l'agent peut choisir d'effectuer ou pas
- Un _environnement_, que les actions viennent modifier
- Un _score_ (_coût_ s'il doit être minimisé, _récompense_ inversement) qui dépend de l'état pré- et post-action de l'environnement ainsi que de l'action qui a été effectuée

La phase d'apprentissage consiste à trouver, par des cycles d'essai/erreur, quelles sont les meilleures actions à prendre en fonction de l'environnement actuel, avec "meilleur" définit comme "qui minimise le coût" (ou maximise la récompense):

#diagram({
  node((0, 0))[Agent]
  edge((0, 0), (1, 0), "->")[Action]
  node((1, 0))[Environnement]
  edge((1, 0), (2, 0), "-->")[Fonction coût]
  node((2, 0))[Score]
  edge((2, 0), (0, 0), "->", bend: 45deg)[Mise à jour]
})

Cette technique est particulièrement adaptée au problèmes qui se prêtent à une modélisation type "jeu vidéo", dans le sens où l'agent représente le personnage-joueur, et le coût un certain score, qui est condition de victoire ou défaite.

En robotique, une approche similaire explore l'espace d'action (en général un courant à envoyer aux moteurs) de façon à optimiser le coût.

En robotique, on a des correspondances claires pour ces quatres notions:

/ Agent: Robot pour lequel on développe le programme de contrôle (appelé _politique_)
/ Actions: Envoi d'ordres aux moteurs, souvent le courant électrique à appliquer // #footnote[il y a techniquement deux principales manières de contrôler un robot: l'envoi de commandes de courant, ou contrôle par puissance, et l'envoi de vitesses cibles, qui laisse la détermination du courant nécéssaire au microcontrolleurs sur le robot même]
/ Environnement: Le monde réel. C'est de loin la partie la plus difficile à simuler informatiquement. On utilise des moteurs de simulation physique, dont la pluralité des implémentations est importante, voir @why_multiple_simulators
/ Coût: Ensemble de contraintes ("ne pas endommager le robot") et d'évaluations spécifiques à la tâche à effectuer ("s'est déplacé de 5m en avant selon l'axe $x$").

=== L'entraînement

Une fois que ce cadre est posé, il reste à savoir _comment_ l'on va trouver la fonction qui associe un état de l'environnement à une action.

Une première approche naïve, mais suffisante dans certains cas, consiste à faire une recherche exhaustive et à stocker dans un simple tableau la meilleure action à faire en fonction de chaque état de l'environnement:

#let exhaustive_memory_table = (caption, filled: false) => {
  let maybe = content => if filled { content } else { [] }
  let loss = x => calc.abs(calc.max(x, 0) - 2)
  let costs = x => (
    $L(#{ x + 1 },) = #{ loss(x + 1) }$,
    $L(#{ calc.max(x - 1, 0) },) = #{ loss(x - 1) }$,
  )

  pad(x: 7%, y: 8%, figure(
    table(
      columns: (2fr, 1.9fr, 1.5fr, 1.5fr),
      align: (left, center, left),
      inset: 8pt,
      table.cell([*État actuel* \ $(x, "retour")$], rowspan: 2),
      table.cell([*Action à effectuer* \ +1 ou -1], rowspan: 2),
      table.cell([*Coûts associés*], colspan: 2),
      [Pour $+1$], [Pour $-1$],

      [ $(0, "C'est plus")$ ], maybe[ +1 ], ..costs(0).map(maybe),
      [ $(1, "C'est plus")$ ], maybe[ +1 ], ..costs(1).map(maybe),
      [ $(3, "C'est moins")$ ], maybe[ -1 ], ..costs(2).map(maybe),
      [ $(4, "C'est moins")$ ], maybe[ -1 ], ..costs(3).map(maybe),
      [ $(5, "C'est moins")$ ], maybe[ -1 ], ..costs(4).map(maybe),
    ),
    caption: caption,
  ))
}

#exhaustive_memory_table(
  filled: false,
)[ Mémoire exhaustive initiale pour un "C'est plus ou c'est moins" dans $[| 0, 5 |] times {"C'est plus", "C'est moins"}$, avec pour solution 2 ]

L'entraînement consiste donc ici en l'exploration de l'entièreté des états possibles de l'environnement, et, pour chaque état, le calcul du coût associé à chaque action possible.

Il faut définir la fonction de coût, souvent appelée $L$ pour _loss_:

$
  L: E -> S
$

avec $E$ l'ensemble des états possibles de l'environnement, et $S$ un ensemble muni d'un ordre total (on utilise souvent $[0, 1]$). Ces fonctions coût, qui ne dépendent que de l'état actuel de l'environnement, représente un domaine du RL#footnote[Reinforcement Learning] appelé _Q-Learning_ @qlearning

On remplit la colonne "Action à effectuer" avec l'action au coût le plus bas:

#exhaustive_memory_table(
  filled: true,
)[ Entraînement terminé, avec pour fonction coût $L = (x, "retour") |-> |x-2|$ la distance à la solution ]

Ici, cette approche exhaustive suffit parce que l'ensemble des états possibles de l'environnement, $E$, posssède 6 éléments

Cependant, ces ensembles sont bien souvent prohibitivement grands (e.g. $x in [| 0, 10^34 |]$), infinis ($x in NN$) ou indénombrables ($x in RR$)

Dans le cas de la robotique, $E$ est une certaine représentation numérique du monde réel autour du robot, on imagine donc bien qu'il y a beaucoup trop d'états possibles.


=== Deep Reinforcement Learning

Une façon de remédier à ce problème de dimensions est de remplacer le tableau exhaustif par un réseau de neurones:

/ État actuel: devient la couche d'entrée
/ Meilleure action: devient la couche de sortie
/ Coûts associés: devient la fonction à optimiser par descente de gradient
/ Le remplissage du tableau: devient la rétropropagation du gradient pendant l'entraînement


#dontbreak[

  ==== Mise à jour (_Q-learning_)

  Le score associé à un état $s_t$ et une action $a_t$, appelée $Q(s_t, a_t)$ ici pour "quality" @qlearning-etymology ou "action-value" @actionvalue, est mis à jour avec cette valeur @maxq:

]

$
  (1 - alpha) underbrace(Q(s_t, a_t), "valeur actuelle") + alpha ( underbrace(R_(t+1), "récompense\npour cette action") + gamma underbrace(max_a Q(S_(t+1), a), "récompense de la meilleure\naction pour l'état suivant") )
$

L'expression comporte deux hyperparamètres, à valeurs dans $]0, 1[$:

/ Learning rate $alpha$: contrôle à quel point l'on favorise l'évolution de $Q$ ou pas. // Il est commun de progressivement baisser $alpha$, ce qui donne lieu à des phases plus "exploratives" ($alpha$ élevé, exploration de nouvelles actions) ou "exploitative" ($alpha$ faible, exploitation des récompenses connues) #refneeded
/ Discount factor $gamma$: contrôle l'importance que l'on donne aux récompenses futures. Il est utile de commencer avec une valeur faible puis l'augmenter avec le temps @maxq-discount.

=== Difficultés liées à l'implémentation de la fonction coût

==== Tendances à la "tricherie" des agents

Expérimentalement, on sait que des tendances "tricheuses" émergent facilement pendant l'entraînement #refneeded: l'agent découvre des séries d'actions qui causent un bug avantageux vis à vis du coût associé, soit parce qu'il y a un bug dans le calcul de l'état de l'environnement post-action, soit parce que la fonction coût ne prend pas suffisemment bien en compte toutes les possibilités de l'environnement (autrement dit, il manque de contraintes).

Dans le cas de la robotique, cela arrive particulièrement souvent #refneeded, et il faut donc un simulateur qui soit suffisamment réaliste.

==== Sous-spécification de la fonction coût

Un exemple populaire est l'expérience de pensée du Maximiseur de trombones @trombones: On imagine un agent avec pour environnement le monde réel, pour actions "prendre des décisions"; "envoyer des emails"; etc. et pour fonction récompense "le nombre de trombones existant sur Terre". Il finirait possiblement par réduire en escalavage tout être vivant capable de produire des trombones: la fonction coût est sous-spécifiée

==== La validation comme méthode de mitigation <why_multiple_simulators>

Comme ces bugs sont des comportements non voulus, il est très probables qu'ils ne soient pas exactement les mêmes en changeant d'implémentation.

Il convient donc de se servir de _plusieurs_ implémentations: une sert à la phase d'entraînement, pendant laquelle l'agent développe des "tendances à la tricherie", puis une autre sert à la phase de _validation_.

Cette phase consiste en le lancement de l'agent dans une autre implémentation, avec les mêmes actions mais qui, crucialement, ne comporte pas les mêmes bugs que l'environnement ayant servi à la phase d'apprentissage.

Les "techniques de triche" ainsi apprises deviennent inefficace, et si le score devient bien pire que celui de l'apprentissage, on peut détecter les cas de triche.

On peut même aller plus loin, et multiplier les phases de validation avec des implémentations supplémentaires, ce qui réduit encore la probabilité qu'une technique de triche se glisse dans l'agent final.

== Évaluation de la performance d'une politique

#let cL = $cal(L)$
#let proba = $bb(P)$
#let setbuilder = (content, with) => ${ #content thick mid(|) thick #with }$

Théoriquement, le score associé à un couple état/action est souvent réduit à l'intervalle $[0, 1]$ et assimilé à une distribution de probabilité: $Q$ est une fonction de $S times A$ vers $[0, 1]$ qui renvoie la probabilité qu'a l'agent à choisir une action en étant dans un état de l'environnement.


On note dans le reste de cette section:

/ $A$: l'ensemble des actions
/ $S$: l'ensemble des états possibles de l'environnement
/ $rho_0: S -> [0, 1]$: la distribution de probabilité de l'état initial de l'environnement. Si l'on initialise l'environnement de manière uniformément aléatoire, $rho_0$ est une équiprobabilité#footnote[i.e. $card rho_0(S) = 1$]
/ $M: S times A -> S$: le moteur de simulation physique, qui applique l'action à un état de l'environnement et envoie le nouvel état de l'environnement
/ $Pi: S -> A$: une politique
/ $Pi^*: S -> A$: la meilleure politique possible, celle que l'on cherche à approcher
/ $R: S -> RR^+$: sa fonction de récompense #todo[incohérent! c'est sensé être $Q$, qu'on a assimilé à une distrib de proba :/]
/ $Q_pi: S times A -> [0, 1]$: la distribution de probabilité d'une politique $pi$, qu'on suppose Markovienne (elle ne dépend que de l'état dans lequel on est). $Q_pi (s_t, a_t)$ est la probabilité que $pi$ choisisse $a_t$, _quand on est dans l'état_ $s_t$ ($s_t$ est l'état *pré*-action, et non post-action)
/ $Q$ (resp. $Q^*$): $Q_Pi$ (resp. $Q_(Pi^*)$), pour alléger les notations
// $R$: $R_Pi$

On suppose $A$ et $S$ dénombrables#footnote[En pratique, $bb(R)$ est discrétisé dans les simulateurs numérique, donc cette hypothèse ne pose pas de problèmes à l'application de la théorie au domaine de la robotique].

Pour alléger les notations, on surchargera les fonctions récompenses pour qu'elle puissent prendre en entrée des éléments de $S times A$, en ignorant simplement l'action choisie:

$
  forall (s, a) in S times A, forall r in "récompenses", r(s, a) := r(s)
$


=== Chemins d'états possibles $cal(C)$



$M$ et $Pi$ forment en fait tout ce qui se passe pendant un pas de temps. c'est cette boucle que l'on répète pour entraîner l'agent (si l'on met $Pi$ à jour à chaque tour de boucle) ou l'utiliser (on parle alors d'inférence):

#diagram(
  node((0, 0), $s_t$),
  edge(corner: right, label-pos: 2 / 8, label-side: left)[choix de l'action],
  edge("->", corner: right, label-pos: 3 / 8, label-side: left)[$Pi$],
  node((1, -1))[$a_t$],
  edge("->", corner: right, label-pos: 5 / 8, label-side: left)[$M$],
  edge(corner: right, label-pos: 6 / 8, label-side: left)[simulation],
  node((2, 0))[$s_(t+1)$],
  edge((2, 0), (2, .75), (0, .75), (0, 0), "-->", label-side: left)[itération],
)

Quand on "déroule" $Pi$ en en partant d'un certain état initial $s_0$, on obtient une suite d'états et d'actions:

#diagram(
  $
    s_0 edge(a_0, ->) & s_1 edge(a_1, ->) & s_2 edge(a_2, ->) & dots.c
  $,
)


Pour tout pas de temps $t in NN$, on a:

$
  cases(
    a_t & = Pi(s_t),
    s_(t+1) & = M(s_t, a_t),
  )
$

On rappelle que $M$ est la fonction "simulation", qui renvoie l'état post-action en fonction de l'action choisie et de l'état pré-action.

Un chemin se modélise aisément par une suite d'éléments de#footnote[Il est essentiel de conserver l'information de l'action prise entre chaque état (contrairement à ce que fournirait une simple suite d'éléments de $S$, par exemple) pour pouvoir calculer les probabilités par rapport à une politique le long d'un chemin. En effet, si l'on veut obtenir la probabilité que $Pi$ ait resulté en un état $s in S$ de l'environnement, il faut savoir "par quelle $a in A$ est-on passé", $Q_Pi$ prenant bien $s$ *et $a$* en entrée.] $S times A$. Ainsi, on note

$
  cal(C)_pi := setbuilder(
    (s_t, a_t)_(t in NN) " avec "
    cases(
      & a_0 & = pi(s_0),
      forall t in NN quad & a_(t+1) & = pi(s_t),
      forall t in NN quad & s_(t+1) & = M(s_t, a_t)
    ),
    s_0 in S
  )
$

l'ensemble des chemins possibles avec la politique $pi$. C'est tout simplement l'ensemble de tout les "déroulements" de la politique $pi$ en partant des états possibles de l'environnement.


On définit également l'ensemble de _tout_ les chemins d'états possibles, peut importe la politique, $cal(C)$ :

$
  cal(C) :=
  setbuilder(
    cases(
      & c_0 & = (s_0, a_0),
      forall t in NN quad & c_(t+1) & = (M(c_t), a_t)
    ),
    (s_0, a) in S times A^NN
  )
$

On notera que, selon $M$, on peut avoir $cal(C) subset.neq (S times A)^NN$: par exemple, certains états de l'environnement peuvent représenter des "impasses", où il est impossible d'évoluer vers un autre état, peut importe l'action choisie.

On note aussi que $cal(C)$ et $cal(C)_pi$ sont dénombrables: Ils sont construits à partir de $(S times A)^NN$ et $S$, et $A$ & $NN$ sont également dénombrables#footnote[
  On a $card cal(C) <= card((S times A)^NN) = card(S times A)^(card NN) = (card S card A)^(card NN) <= (aleph_0)^(card NN) = attach(aleph_0, tl: 2) = aleph_0$. De plus, $cal(C)_pi subset cal(C)$, donc $card cal(C)_pi <= card cal(C) <= aleph_0$
]

#align(center)[
  _Cette formalisation est utile par la suite, \ pour proprement définir certaines grandeurs._
]

*Remarque*

Les définitions suivantes, dont la plupart proviennent du papier _Trust Region Policy Optimization_, citation "@trpo", ont été reformulées pour utiliser cette notion de chemins.

#{
  show math.equation: math.display


  [
    #todo[Pas clair]

    Notamment, les espérances le long d'un chemin, notées $inline(exp_(s_0, a_0, ...))$ dans @trpo, sont dénotées ici par une opération-sur-ensemble usuelle#footnote[d'autres exemples d'"opérations-sur-ensemble" sont $sum_(x in RR)$ ou $product_(n in NN)$, par exemple.], avec $exp_(c in cal(C))$. De même, la notation $inline(exp_(s_0, a_0, ... ~ pi))$ est dénotée $exp_(c ~ pi in cal(C))$ et explicitée après @eta-exp-definition.

    Dans la documentation de _OpenAI Spinning Up_ (citation "@trpo-openai"), les espérances sont notées $op(E, limits: #true)_(s, a ~ pi)$, ce qui correspond à faire une espérance _le long_ de tout chemin: cela correspond ici à $exp_(c ~ pi in cal(C)) sum_(t=0)^oo dots.c$.
  ]
}


=== Récompense attendue $eta$

$eta$ représente la récompense moyenne à laquelle l'on peut s'attendre pour une politique $pi$ avec fonction de récompense $r$.

Elle prend en compte le _discount factor_ $gamma$ : les récompenses des actions deviennent de moins en moins importantes avec le temps. $eta$ est définie ainsi @trpo

#let policyexp = policy => $exp_((c_t)_(t in NN) op(~) #policy op(in) cal(C))$

$
  eta(pi, r) :=
  underbracket(
    sum_((c_t)_(t in NN) in cal(C))
    underbracket(
      rho_0(s_0)
      product_(t=0)^oo Q_pi (c_t), "probabilité du chemin"
    )
    quad
    underbracket(sum_(t=0)^oo gamma^t r(c_t), "récompense associée"),
    "pour tout chemin possible"
  )
$ <eta-sum-definition>


On peut également exprimer $eta(pi, r)$ comme une espérance. On a (cf @proof-eta-esperance)

$
  eta(pi, r) = exp_(C ~ pi in cal(C))(sum_(t=0)^oo gamma^t r(C_t))
$ <eta-exp-definition>


Avec $C ~ pi in cal(C)$ signifiant

- $C$ est une variable aléatoire à valeurs dans $cal(C)$
- $C$ suit la même loi que $pi$


=== Avantage $A$

// Le >= #h(-1pt) ""_f dans la footnote c'est un hack pour mettre f en subscript inline de >= , sinon ça passe en dessous et c'est moche

L'avantage $A_(pi, r)(s, a)$ mesure à quel point  il est préférable de choisir l'action $a$ quand on est dans l'état $s$ (pour la politique $pi$, avec "préférable" au sens de#footnote[En posant, pour toute fonction $f: I -> O$, avec $O$ ordonné par $>=$: $forall i in I^2, quad i_1 op(>=#h(-1pt) ""_f) i_2 := f(i_1) >= f(i_2)$. Ici donc, on compare les politiques selon $a |-> r(M(s, a))$. Autrement dit, la récompense associé à l'état obtenu après le choix d'une action, depuis l'état $s$] $>=_(r(M(s, dot.c)))$)

Pour calculer $A_(pi, r)(s, a)$, on regarde l'espérance des récompenses cumulées pour tout chemin commençant par $s$, et on la compare à celle pour tout chemin commençant par $M(s, a)$

$
  A_(pi, r)(s, a) :=
  underbracket(
    exp_((s_t, a_t)_(t in NN) op(~) pi op(in) cal(C) \ s_0 = s \ s_1 = M(s_0, a)) sum_(t=0)^oo gamma^t r(s_t),
    Q(s, a)
  ) - underbracket(
    exp_((s_t, a_t)_(t in NN) op(~) pi op(in) cal(C) \ s_0 = s) sum_(t=0)^oo gamma^t r(s_t),
    V(s)
  )
$


On peut visualiser ce calcul ainsi:

#let height = 2
#diagram({
  // Prior path
  node((0, 0))[$dots.c$]
  edge("->")[$a_(t-2)$]
  node((1, 0))[$s_(t-1)$]
  edge("->")[$a_(t-1)$]

  // Main-branch path
  node((2, 0), name: <break>)[$s_t$]
  edge("-")[]
  node((3.5, 0))
  edge("->", label-pos: 0%)[$a_t$]
  node((4.5, 0))[$sum_(i=t+1)^oo gamma^t r(s_i)$]

  // Bottom-branch path
  node(name: <bottom>, (4.5, +1.5))[$sum_(i=t+1)^oo gamma^t r(s'_i)$ ]
  node((5.75, +1.5), align(
    left,
  )[si $Pi$ avait choisit $a'_t$ \ au lieu de $a_t$])
  edge(<break>, <bottom>, "->", bend: -25deg)[$a'_t$]

  // top-branch path
  node(name: <top>, (4.5, -1.5))[$sum_(i=t+1)^oo gamma^t r(s''_i)$]
  node((5.75, -1.5), align(
    left,
  )[si $Pi$ avait choisit $a''_t$ \ au lieu de $a_t$])
  edge(<break>, <top>, "->", bend: 25deg)[$a''_t$]

  // Expectation bar V(s)
  node((5, height))
  edge("--")
  node((1.85, height))
  edge("-", label-side: left, label-pos: 75%)[$exp$]
  node((1.85, -height))
  edge("--")[$V(s_t)$]
  node((5, -height))

  // Expectation bar Q(s, a)
  node((5, 0.5))
  edge("--")
  node((3.25, 0.5))
  edge("-", label-side: left, label-pos: 75%)[$exp$]
  node((3.25, -0.5))
  edge("--")[$Q(s_t, a_t)$]
  node((5, -0.5))
})



On considère tout les chemins à partir de l'état $s_t$, et l'on regarde l'espérance...

/ pour $V(s_t)$: de tout les chemins
/ pour $Q(s_t, a_t)$: du chemin où l'on a choisi $a_t$

En suite, il suffit de faire la différence, pour savoir l'_avantage_ que l'on a à choisir $a_t$ par rapport au reste.

/*

La preuve dans TRPO est incompréhensible, genre le A_pi(s) dans l'expression de eta(pi~) devient magiqueent r(s_t) + gamma V_pi(s_(t+1)) - V_pi(s_t) alors que c'est dit juste avant que A_pi(s) = exp(r(s) + ...)

genre l'exp disparaît comme as
*/

=== Lien entre $eta$ et $A$

Pour une fonction de récompense $r$ donnée, $A$ permet de calculer $eta$ pour une politique $pi$ en fonction de la valeur de $eta$ pour une autre politique $pi'$ @trpo

$
  eta(pi', r) & = eta(pi, r) + policyexp(pi') sum_(t=0)^oo gamma^t A_(pi, r)(c_t)
$


=== _Surrogate advantage_ $cL$

Il est théoriquement possible d'utiliser $A$ pour optimiser une politique, en maximisant sa valeur:

#diagram(
  caption: [Boucle d'entraînement],
  node((0, 0))[$s_t$],
  edge("-"),
  node(name: <policy>, (0, -1))[$Pi$],
  edge("->", corner: right),
  node((1, -2))[$a_t$],
  edge("->", corner: right)[$M$],
  node(name: <final>, (2, 0))[$s_(t+1)$],
  edge(<final>, (0, 0), "-->", label-side: left)[itération],
  // edge("d,d,l,l,l,u,u,u", <policy>, "->", label-pos: 33%, label-side: left, align(center, [$Q_Pi(s_(t+1), argmax_(a in A) A_(Pi, R)(s_(t+1), a)) <- A_(Pi, R) (dots)$ \ Mise à jour]))
  // edge("d,d,l,l,l,u,u,u", <policy>, "->", label-pos: 37%, label-side: left, align(center)[$argmax_(a in A) A_(Pi, R)(s_(t+1), a)$ \ mise à jour de $Pi$])
  edge("d,l,l,l,u,u", <policy>, "->", label-pos: 33%, label-side: left, align(
    center,
  )[
    //   mise à jour de $Pi$ \
    $Q_Pi(s_(t+1), a_(t+1)^*) <- A_(Pi, R)(s_(t+1), a_(t+1)^*)$
  ]),
) <policy-update-loop>

Avec

$
  a_(t+1)^* & := argmax_(a in A) A_(Pi, R)(s_(t+1), a) \
$

Mais, en pratique, des erreurs d'approximation peuvent rendre $A_(Pi, R)(s_(t+1), a_(t+1)^*)$ négatif, ce qui empêche de s'en servir pour définir une valeur de $Q_(Pi)$ @trpo


Le _surrogate advantage_ détermine la performance d'une politique par rapport à une autre @trpo-openai

$
  cL_r (pi', pi) := exp_((s_t, a_t)_(t in NN) in cal(C)) sum_(t=0)^oo (Q_pi (s_t, a_t)) / (Q_pi' (s_t, a_t)) A_(pi, r)(s_t, a_t)
$


== Méthodes d'optimisation de politique

=== _Trust Region Policy Optimization_



La méthode TRPO définit la mise à jour de $Q$ avec un $Q'$ qui maximise le _surrogate advantage_ @trpo-openai, sous une contrainte limitant l'ampleur des modifications individuelles, ce qui procure une stabilité à l'algorithme, et évite qu'un seul "faux pas" dégrade violemment la performance de la politique.

$
  Q' = & cases(
           argmax_(q) cL_r (q, Q),
           "s.c.  distance"(Q', Q) < delta
         )
$

Avec $delta$ une limite supérieure de distance entre $Q'$, la nouvelle politique, et $Q$, l'ancienne.

==== Distance entre politiques

Il existe plusieurs manières de mesurer l'écart entre deux distributions de probabilité, dont notamment la _divergence de Kullback-Leibler_, aussi appelée entropie relative @kullback-leibler @kullback-leibler2:

$
  D_"KL" (P || P') := sum_(x in cal(X)) P(x) log P(x) / (P'(x))
$

Avec $cal(X)$ l'espace des échantillons et $P, P'$ deux distributions de probabilité sur celui-ci. Dans notre cas, $cal(X) = S times A$,



Pour évaluer cette distance, on regarde la plus grande des distances entre des paires de distributions de probabilité de politiques $Q_Pi$ et $Q_Pi'$, pour tout $s in S$ @trpo

$
  max_(s in S) D_"KL" (Q_Pi' (s, dot) || Q_Pi (s, dot)) < delta
$


En notant $Q_pi (s, dot) := a |-> Q_pi (s, a)$. On a donc ici "$cal(X) = A$" dans la définition de $D_"KL"$

==== Pourquoi faire le maximum sur chaque $s in S$ ?

Ce maximum revient à limiter non pas la simple distance entre les deux politiques, mais _limiter la modification de la politique sur chacune de ses actions_.

Ceci permet d'éviter d'avoir deux politiques jugées similaires par $D_"KL"$ à cause de modifications se "compensant". Par exemple, avec

#let si = $& quad "si"$
#let sinon = $& quad "sinon"$


$
  forall s in S, Q(s, 1) = Q(s, 2)
$


et

$
  Q' := (s, a) |-> cases(
    Q(s, a) dot 2 si a = 1,
    Q(s, a) dot 1/2 si a = 2,
    Q(s, a) sinon
  )
$

On a $D_"KL" (Q, Q') = 0$ (cf @dkl-zero), alors qu'il y a eu une modification très importante des probabilités de choix de l'action 1 et 2 dans tout les états possibles : si on imagine $Q(s, 1) = Q(s, 2) = 1 slash 4$, on a après modification $Q'(s, 1) = 1 slash 2$ et $Q'(s, 2) = 1 slash 8$.

==== Région de confiance

Cette contrainte définit un ensemble réduit de $Pi'$ acceptables comme nouvelle politique, aussi appelé une _trust region_ (région de confiance), d'où la méthode d'optimisation tire son nom @trpo.

#let ddot = [ #sym.dot #h(-1em / 16) #sym.dot ]

#dontbreak[

En pratique, l'optimisation sous cette contrainte est trop demandeuse en puissance de calcul, on utilise plutôt l'espérance @trpo.

$
  overline(D_"KL") := bb(E)_(s in S) D_"KL" (Q(s, dot) || Q'(s, dot))
$

]



=== _Proximal Policy Optimization_

La _PPO_ repose sur le même principe de stabilisation de l'entraînement par limitation de l'ampleur des changements de politique à chaque pas.

Cependant, les méthodes _PPO_ préfèrent changer la quantité à optimiser, pour limiter intrinsèquement l'ampleur des modifications, en résolvant un problème d'optimisation sans contraintes @ppo


$
  argmax_(Pi') & exp_((s, a) in cal(C)) L(s, a, Pi, Pi', R) \
        "s.c." & top
$

==== Avec pénalité _(PPO-Penalty)_

_PPO-Penalty_ soustrait une divergence K-L pondérée à l'avantage:

$
  L(s, a, Pi, Pi', R) = (Q_Pi (s, a)) / (Q_Pi' (s, a)) A_(Pi, R) (s, a) - beta D_"KL" (Pi || Pi')
$

Avec $beta$ ajusté automatiquement pour être dans la même échelle que l'autre terme de la soustraction.

==== Par _clipping_ _(PPO-Clip)_

_PPO-Clip_ utilise une limitation du ratio de probabilités (en minimum et en maximum) @ppo-openai


$
  L(s, a, Pi, Pi', R) = min(
    & (Q_Pi' (s, a)) / (Q_Pi (s, a)) A_(Pi', R)(s, a), quad \
    &op("clip")(
      (Q_Pi' (s, a)) / (Q_Pi (s, a)),
      1 - epsilon,
      1 + epsilon
    ) A_(Pi', R)(s, a)
  )
$

Avec $epsilon in RR_+^*$ un paramètre indiquant à quel point l'on peut s'écarter de la politique précédente, et

$
  op("clip") := (x, m, M) |-> cases(
    m si x < m,
    M si x > M,
    x sinon
  )
$

La complexité de l'expression, et la présence d'un $min$ au lieu de simplement un $op("clip")$ est dûe au fait que l'avantage $A_(Pi', R) (s, a)$ peut être négatif. L'expression se simplifie en séparant les cas (cf @proof-ppo-clip-simplify)

#let named_point = (
  x,
  y,
  shape: "@",
  color: black,
  side: right,
  content,
) => edge(
  (x, y),
  shape + "-",
  (x + 0.01, y),
  label-side: side,
  stroke: color,
  text(fill: color, content),
)

#let equation_and_diagram = (eqn, diagrm) => stack(
  dir: ltr,
  block(width: 70%, math.equation(numbering: none, block: true, eqn)),
  diagrm,
)

#dontbreak[

  / Si l'avantage est positif: $a$ est un meilleur choix que $Pi(s)$.

  #equation_and_diagram(
    $
      L(s, a, Pi, Pi', R) = min(
        (Q_Pi' (s, a)) / (Q_Pi (s, a)),
        quad 1 + epsilon
      ) A_(Pi', R)(s, a)
    $,
    diagram(
      spacing: (2.7em, 2em),
      node((-1, 0))[$Pi'$],
      edge((-1, 0), "->", (3, 0), stroke: luma(150)),
      edge((-1, 0), "-|", (1, 0), extrude: (1, -1, 0)),
      named_point(1, 0, shape: "|")[$1+epsilon$],
      named_point(0, 0)[$Pi$],
      named_point(1.5, 0, color: red, side: left)[$times$],
      named_point(0.5, 0, color: olive, side: left)[$checkmark$],
    ),
  )

  / Si l'avantage est négatif: choisir $a$ est pire que garder $Pi(s)$.

  #equation_and_diagram(
    $
      L(s, a, Pi, Pi', R) = max(
        1 - epsilon, quad
        (Q_Pi' (s, a)) / (Q_Pi (s, a))
      ) A_(Pi', R)(s, a)
    $,
    diagram(
      spacing: (2.7em, 2em),
      node((3, 0))[$Pi'$],
      edge((-1, 0), "<-", (3, 0), stroke: luma(150)),
      edge((1, 0), "|-", (3, 0), extrude: (1, -1, 0)),
      named_point(1, 0, shape: "|")[$1-epsilon$],
      named_point(2, 0)[$Pi$],
      named_point(0, 0, color: red, side: left)[$times$],
      named_point(1.5, 0, color: olive, side: left)[$checkmark$],
    ),
  )

]


== Application en robotique


=== Spécification de la tâche

Le score (récompense ou coût) dépend de la tâche pour laquelle on veut entraîner l'agent.

En robotique, il est commun d'inclure dans la récompense les éléments suivants:

- Couple maximal sur les commandes envoyées au moteurs
- Limite sur la vélocité du robot
- Prévention des auto-collisions (par exemple, le bras qui tape la jambe)
- #todo[Ajouter @maciej]
- etc.


=== Inventaire des simulateurs en robotique


Dans le contexte de la robotique, le calcul de l'état post-action de l'environnement est le travail du _moteur de physique_.

Bien évidemment, ce sont des programmes complexes avec des résolutions souvent numériques d'équation physiques; il est presque inévitable que des bugs se glissent dans ces programmes.




Un environnement de RL#footnote[Reinforcement Learning] ne se résume pas à son moteur de physique: il faut également charger des modèles 3D, le modèle du robot (qui doit être contrôlable par les actions, on fait donc une émulation de la partie logicielle du robot), et également, pendant les phases de développement, avoir un moteur de rendu graphique, une interface et des outils de développement.

Cet ensemble s'appelle un _simulateur système_.

==== Isaac

Un simulateur développé par NVIDIA @isaacsim, utilisant son propre moteur de rendu, PhysX @physx

==== MuJoCo

Un simulateur initialement propriétaire. Il a été rendu gratuit puis open source par Google DeepMind @mujoco.

Bien que MuJoCo est décrit comme un moteur de simulation physique et non un simulateur, il embarque une commande `simulate` qui le rend fonctionnellement équivalent à un simulateur @mujoco-simulate.

==== Gazebo

Les intérêts de Gazebo @gazebo sont multiples:

- C'est un logiciel open-source _communautaire_, qui ne dépend pas du financement d'une grande entreprise
- Son architecture modulaire permet notamment d'utiliser plusieurs moteurs de simulation physique différents @gazebo-physics-engines, à l'inverse de MuJoCo.
- C'est un _simulateur système_, qui est capable de simuler la partie logicielle du robot en plus de la physique du son modèle 3D.

Gazebo possède des plugins officiels pour divers moteurs de simulation physique:

/ DART: Plugin `gz-physics-dartsim-plugin`, c'est l'implémentation principale, et celle par défaut @gazebo-physics-engines @dart.
/ Bullet: Plugin `gz-physics-bulletsim-plugin`. En beta @gazebo-physics-engines @bullet @pybullet.
/ Bullet Featherstone: Plugin `gz-physics-bullet-featherstone-plugin`, également en beta @gazebo-physics-engines. Une variable de Bullet, utilisant l'algorithme de Featherstone @bullet-featherstone @featherstone


== Reproductibilité logicielle

La reproductibilité est particulièrement complexe dans le champ du reinforcement learning @rl-reproducibility.

En plus des difficultés de reproductibilité sur l'algorithme lui-même, le paysage logiciel et matériel est riche en dépendances à des bibliothèques, qui elle aussi dépendent d'autres bibliothèques.

#figure(
  caption: [Arbre des dépendances pour _Gepetto/h1v2-Isaac_],
  scale(7%, reflow: true, diagraph.render(read("./isaac-deptree.dot"))),
)

Bien que toutes ces dépendances puissent être spécifiées avec des contraintes de version strictes @lockfiles pour éviter des changements imprévus de comportement du code venant des bibliothèques, beaucoup celles-ci ont besoin de compiler du code C++ _à l'installation_#footnote[Pour des raisons de performance @cpp-python, certaines bibliothèques implémentent leurs fonctions critiques en C++. C'est par exemple le cas de NumPy #refneeded]: fixer la version de la bibliothèque ne suffit pas donc à guarantir la reproductibilité de la compilation de l'arbre des dépendances.
