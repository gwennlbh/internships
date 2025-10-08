#import "@preview/fletcher:0.5.8": diagram, node, edge

#let comment = content => text(fill: gray)[(Note: #content)]

#show terms: it => grid(
    columns: 2, row-gutter: 1em, column-gutter: (15pt, 0pt), align: (left, left),
    ..it.children.map(item =>
      (strong(item.term), item.description)
    ).flatten()
  )

== Bases théoriques du _Reinforcement Learning_

L'apprentissage par renforcement, ou _Reinforcement Learning_, permet de développer des programmes sans expliciter leur logique: on décrit plutôt quatre choses, qui vont permettre à la logique d'émerger pendant la phase d'entraînement:

- Un _agent_: c'est le programme que l'on souhaite créer
- Des _actions_ que l'agent peut choisir d'effectuer ou pas
- Un _environnement_, que les actions viennent modifier
- Un _coût_ (ou _récompense_) qui dépend de l'environnement

La phase d'apprentissage consiste à trouver, par des cycles d'essai/erreur, quelles sont les meilleures actions à prendre en fonction de l'environnement actuel, avec meilleur définit comme "qui minimise le coût" (ou maximise la récompense):

#align(center, diagram(
  node((0, 0))[Agent],
  edge((0, 0), (1, 0), "->")[Action],
  node((1, 0))[Environnement],
  edge((1, 0), (2, 0), "-->")[Fonction coût],
  node((2, 0))[Coût],
  edge((2, 0), (0, 0), "->", bend: 45deg)[Mise à jour]
))

Cette technique est particulièrement adaptée au problèmes qui se prêtent à une modélisation type "jeu vidéo", dans le sens où l'agent représente le personnage-joueur, et le coût un certain score, qui est condition de victoire ou défaite.

En robotique, on a des correspondances claires pour ces quatres notions:

/ Agent: Robot pour lequel on développe le programme de contrôle (appelée une _politique_)
/ Actions: Envoi d'ordres aux moteurs // #footnote[il y a techniquement deux principales manières de contrôler un robot: l'envoi de commandes de courant, ou contrôle par puissance, et l'envoi de vitesses cibles, qui laisse la détermination du courant nécéssaire au microcontrolleurs sur le robot même]
/ Environnement: Le monde réel. C'est de loin la partie la plus difficile à simuler informatiquement. On utilise des moteurs de simulation physique, dont la multiplicité des implémentations est importante, voir @simulators
/ Coût: un ensemble de contraintes ("ne pas endommager le robot"), dont la plupart dépendent de l'objectif de la politique

=== L'entraînement

Une fois que ce cadre est posé, il reste à savoir _comment_ l'on va trouver la fonction qui associe un état de l'environnement à une action.

Une première approche naïve, mais suffisante dans certains cas, consiste à faire une recherche exhaustive et à stocker dans un simple tableau la meilleure action à faire en fonction d'un état de l'environnement:

#let exhaustive_memory_table = (caption, filled: false) => {
  let maybe = content => if filled { content } else { [] }
  let costs = (plus_one, minus_one) => [ $L(x+1,) = #plus_one quad  L(x-1,) = #minus_one$ ]
  pad(x: 7%, y: 10%, figure(
    table(
      columns: (2fr, 1.9fr, 3fr),
      align: (left, center, left),
      inset: 8pt,
      [*État actuel* \ $(x, "retour")$], [*Meilleure action* \ +1 ou -1], [*Coûts associés* \ #maybe[avec $L = (x, "retour") |-> |x-2|$]],
      [ $(0, "C'est plus")$ ], maybe[ +1 ], maybe(costs(2, 2)),
      [ $(1, "C'est plus")$ ], maybe[ +1 ], maybe(costs(1, 2)),
      [ $(3, "C'est moins")$ ], maybe[ -1 ], maybe(costs(2, 3)),
      [ $(4, "C'est moins")$ ], maybe[ -1 ], maybe(costs(3, 4)),
      [ $(5, "C'est moins")$ ], maybe[ -1 ], maybe(costs(4, 5))
    ), 
    caption: caption 
  ))
}

#exhaustive_memory_table(filled: false)[ Exemple d'agent à mémoire exhaustive pour un "C'est plus ou c'est moins" dans ${ 0, 1, 2 }$, avec pour solution 2 ]

L'entraînement consiste donc ici en l'exploration de l'entièreté des états possibles de l'environnement, et, pour chaque état, le calcul du coût associé à chaque action possible. 

Il faut définir la fonction de coût, souvent appelée $L$ pour _loss_:

$
L: E -> S
$

avec $E$ l'ensemble des états possibles de l'environnement, et $S$ un ensemble muni d'un ordre total (on utilise souvent $[0, 1]$)

Quand on parle de "coût d'une action", on parle du coût de l'état résultant de l'application de l'action en question à l'état actuel//: $ L: E times A -> S = (e, a) |-> L(a(e))$

On remplit la colonne "Action à effectuer" avec l'action au coût le plus bas: 

#exhaustive_memory_table(filled: true)[ Entraînement terminé, avec pour fonction coût $L$ la distance à la solution ]

Ici, cette approche exhaustive suffit parce que l'ensemble des états possibles de l'environnement, $E$, posssède 6 éléments

Cependant, ces ensembles sont bien souvent prohibitivement grands (e.g. $x in [| 0, 10^34 |]$), infinis ($x in NN$) ou indénombrables ($x in RR$)

Dans le cas de la robotique, $E$ est une certaine représentation numérique du monde réel autour du robot, on imagine donc bien qu'il y a beaucoup trop d'états possibles.


==== Deep Reinforcement Learning

Une façon de remédier à ce problème de dimensions est de remplacer le tableau exhaustif par un réseau de neurones:

/ État actuel: devient la couche d'entrée
/ Meilleure action: devient la couche de sortie
/ Coûts associés: deviennent les neurones des couches cachées
/ Le remplissage du tableau: devient la rétropropagation pendant l'entraînement


=== Nécéssité de la validation

Expérimentalement, on sait que des tendances "tricheuses" émergent facilement pendant l'entraînement: l'agent découvre des séries d'actions qui causent un bug avantageux vis à vis du coût associé, soit parce qu'il y a un bug dans le calcul de l'état de l'environnement post-action, soit parce que la fonction coût ne prend pas suffisemment bien en compte toutes les possibilités de l'environnement (autrement dit, il manque de contraintes).

==== Sous-spécification de la fonction coût

#comment[ Bof cette partie ]

Un exemple populaire est l'expérience de pensée du Maximiseur de trombones @trombones: un agent avec pour environnement le monde réel, pour actions "prendre des décisions"; "envoyer des emails"; etc. et pour fonction récompense (une fonction à maximiser au lieu de minimiser) "le nombre de trombones existant sur Terre", finirait possiblement par réduire en escalavage tout être vivant capable de produire des trombones: la fonction coût est sous-spécifiée

==== Bug dans un moteur de physique

Dans le contexte de la robotique, le calcul de l'état post-action de l'environnement est le travail du _moteur de physique_.

Bien évidemment, ce sont des programmes complexes avec souvent des résolutions numériques d'équation physiques, il est presque inévitable que des bugs se glissent dans ces programmes.

Ces phénomènes, appelés _"glitches"_ dans le jargon du jeu vidéo, peuvent se manifester de diverses manières:

#comment[ Compliqué sans vidéo... ptet à remplacer par une phrase seulement, ou alors c'est peut-être déjà assez clair sans exemples? ]

- Le passage à travers un objet solide à cause de cas limites dans les calculs de collision joueur-objet (appelé _No clip_)
- La téléportation du joueur sur des grandes distances sans cause raisonnable, souvent causé par des erreurs dans le calcul des coordonnées de sa position
- La projection d'un objet a une vitesse extrême, souvent causé par des cas limites dans le calcul de la vélocité lors d'une collision

Bien évidemment, pour l'agent, tant qu'un bug n'est pas explicitement découragé par sa prise en compte dans la fonction coût, si l'état résultant améliore le score, l'agent apprendra à faire cette action quand c'est utile.

#comment[ Rien à voir mais je me dis, c'est enfait un moyen de trouver des bugs dans un physics engine ! ça me fait penser au Fuzzing un peu, mais avec un NN plutôt que du hasard contrôlé ]

==== 

== Application en robotique

== Le H1v2 d'_Unitree_

== Environnements et moteurs de simulation physique <simulators>

=== MuJoCo

=== Gazebo 

== Reproductibilité logicielle
