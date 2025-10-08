#import "@preview/fletcher:0.5.8": diagram, node, edge

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
  pad(x: 10%, figure(
    table(
      columns: (1fr, 1fr, 1fr),
      align: left,
      inset: 8pt,
      [*État courant* $(x, "retour")$], [*Action à effectuer* +1 ou -1], [*Coûts associés*],
      [ $(0, "C'est plus")$ ], maybe[ +1 ], maybe[ $+1 |-> 2, -1 |-> 2$ ],
      [ $(1, "C'est plus")$ ], maybe[ +1 ], maybe[ $+1 |-> 1, -1 |-> 2$ ],
      [ $(3, "C'est moins")$ ], maybe[ -1 ], maybe[ $+1 |-> 2, -1 |-> 1$ ],
      [ $(4, "C'est moins")$ ], maybe[ -1 ], maybe[ $+1 |-> 3, -1 |-> 2$ ],
      [ $(5, "C'est moins")$ ], maybe[ -1 ], maybe[ $+1 |-> 4, -1 |-> 3$ ],
    ), 
    caption: caption 
  ))
}

#exhaustive_memory_table(filled: false)[ Exemple d'agent à mémoire exhaustive pour un "C'est plus ou c'est moins" dans ${ 0, 1, 2 }$, avec pour solution 2 ]

L'entraînement consiste donc ici en l'exploration de l'entièreté des états possibles de l'environnement, et, pour chaque état, le calcul du coût associé à chaque action possible. On remplit la colonne "Action à effectuer" avec l'action associée au coût le plus bas. 

On peut définir la fonction coût par la distance de $x$ à la solution: $(x, "retour") |-> | x - 2 |$

#exhaustive_memory_table(filled: true)[ Entraînement terminé ]

Ici, cette approche exhaustive suffit parce que l'ensemble des états possibles de l'environnement, $E$, posssède 6 éléments//:

// $
// "card" E &= "card" ( { "C'est plus", "C'est moins" } times { 0, 1, 2 } ) \
// &= "card" { "C'est plus", "C'est moins" } dot "card" { 0, 1, 2 }  \
// &= 2 dot 3 = 6 
// $

Cependant, ces ensembles sont bien souvent prohibitivement grands (e.g. $n in [| 0, 10^34 |]$), infinis ($n in NN$) ou indénombrables ($n in RR$)

Dans le cas de la robotique, $E$ est une certaine représentation numérique du monde réel autour du robot, on imagine donc bien qu'il y a beaucoup trop d'états possibles.


==== Deep Reinforcement Learning

Une façon de remédier à ce problème de dimensions est de remplacer le tableau exhaustif par un réseau de neurones.


=== Tendances à la "tricherie" des agents



== Application en robotique

== Le H1v2 d'_Unitree_

== Environnements et moteurs de simulation physique <simulators>

=== MuJoCo

=== Gazebo 

== Reproductibilité logicielle
