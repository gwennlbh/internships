#import "@preview/fletcher:0.5.8": diagram, node, edge


#let comment = content => text(fill: gray)[(Note: #content)]
#let todo = content => text(fill: red)[(TODO: #content)]
#let refneeded = text(fill: luma(100), [[Réf. nécéssaire]])

== Bases théoriques du _Reinforcement Learning_

L'apprentissage par renforcement, ou _Reinforcement Learning_, permet de développer des programmes sans expliciter leur logique: on décrit plutôt quatre choses, qui vont permettre à la logique d'émerger pendant la phase d'entraînement:

- Un _agent_: c'est le programme que l'on souhaite créer
- Des _actions_ que l'agent peut choisir d'effectuer ou pas
- Un _environnement_, que les actions viennent modifier
- Un _score_ (_coût_ s'il doit être minimisé, _récompense_ inversement) qui dépend de l'état pré- et post-action de l'environnement ainsi que de l'action qui a été effectuée

La phase d'apprentissage consiste à trouver, par des cycles d'essai/erreur, quelles sont les meilleures actions à prendre en fonction de l'environnement actuel, avec meilleur définit comme "qui minimise le coût" (ou maximise la récompense):

#align(center, diagram(
  node((0, 0))[Agent],
  edge((0, 0), (1, 0), "->")[Action],
  node((1, 0))[Environnement],
  edge((1, 0), (2, 0), "-->")[Fonction coût],
  node((2, 0))[Score],
  edge((2, 0), (0, 0), "->", bend: 45deg)[Mise à jour]
))

Cette technique est particulièrement adaptée au problèmes qui se prêtent à une modélisation type "jeu vidéo", dans le sens où l'agent représente le personnage-joueur, et le coût un certain score, qui est condition de victoire ou défaite.

En robotique, on a des correspondances claires pour ces quatres notions:

/ Agent: Robot pour lequel on développe le programme de contrôle (appelée une _politique_)
/ Actions: Envoi d'ordres aux moteurs // #footnote[il y a techniquement deux principales manières de contrôler un robot: l'envoi de commandes de courant, ou contrôle par puissance, et l'envoi de vitesses cibles, qui laisse la détermination du courant nécéssaire au microcontrolleurs sur le robot même]
/ Environnement: Le monde réel. C'est de loin la partie la plus difficile à simuler informatiquement. On utilise des moteurs de simulation physique, dont la multiplicité des implémentations est importante, voir @why_multiple_simulators
/ Coût: un ensemble de contraintes ("ne pas endommager le robot"), dont la plupart dépendent de l'objectif de la politique

=== L'entraînement

#todo[Expliquer exploration vs exploitation et $gamma$]

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

avec $E$ l'ensemble des états possibles de l'environnement, et $S$ un ensemble muni d'un ordre total (on utilise souvent $[0, 1]$). Ces fonctions coût, qui ne dépendent que de l'état actuel de l'environnement, représente un domaine du RL#footnote[Reinforcement Learning] appelé _Q-Learning_ @qlearning

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


=== Tendances à la "tricherie" des agents

Expérimentalement, on sait que des tendances "tricheuses" émergent facilement pendant l'entraînement #refneeded: l'agent découvre des séries d'actions qui causent un bug avantageux vis à vis du coût associé, soit parce qu'il y a un bug dans le calcul de l'état de l'environnement post-action, soit parce que la fonction coût ne prend pas suffisemment bien en compte toutes les possibilités de l'environnement (autrement dit, il manque de contraintes).

==== Sous-spécification de la fonction coût

#comment[ Bof cette partie ]

Un exemple populaire est l'expérience de pensée du Maximiseur de trombones @trombones: un agent avec pour environnement le monde réel, pour actions "prendre des décisions"; "envoyer des emails"; etc. et pour fonction récompense (une fonction à maximiser au lieu de minimiser) "le nombre de trombones existant sur Terre", finirait possiblement par réduire en escalavage tout être vivant capable de produire des trombones: la fonction coût est sous-spécifiée

==== Bug dans l'implémentation de l'environnement


Bien évidemment, pour l'agent, tant qu'un bug n'est pas explicitement découragé par sa prise en compte dans la fonction coût. Si une action est favorable à l'amélioration du score, l'agent la prendra.


==== La validation comme méthode de mitigation <why_multiple_simulators>
#comment[ça se dit mitigation en français?]

Comme ces bugs sont des comportements non voulus, il est très probables qu'ils ne soient pas exactement les mêmes d'implémentation à implémentation du même environnement.

Il convient donc de se servir de _plusieurs_ implémentations: un sert à la phase d'entraînement, pendant laquelle l'agent développe des "tendances à la tricherie", puis une phase de _validation_.

Cette phase consiste en le lancement de l'agent dans une autre implémentation, avec les mêmes actions mais qui, crucialement, ne comporte pas les mêmes bugs que l'environnement ayant servi à la phase d'apprentissage.

Les "techniques de triche" ainsi apprises deviennent inefficace, et si le score (le coût ou la récompense) devient bien pire que pendant l'apprentissage, on peut détecter les cas de triche.

On peut même aller plus loin, et multiplier les phases de validation avec des implémentations supplémentaires, ce qui réduit encore la probabilité qu'une technique de triche se glisse dans l'agent final

#comment[ Rien à voir mais je me dis, c'est enfait un moyen de trouver des bugs dans un physics engine ! ça me fait penser au Fuzzing un peu, mais avec un NN plutôt que du hasard contrôlé ]


== Application en robotique


Dans le contexte de la robotique, le calcul de l'état post-action de l'environnement est le travail du _moteur de physique_.

Bien évidemment, ce sont des programmes complexes avec souvent des numériques souvent numériques d'équation physiques; il est presque inévitable que des bugs se glissent dans ces programmes.

Un environnement de RL#footnote[Reinforcement Learning] ne se résume pas à son moteur de physique: il faut également charger des modèles 3D, le modèle du robot (qui doit être contrôlable par les actions), et également, pendant les phases de développement, avoir un moteur de rendu graphique, une interface et des outils de développement.

Cet ensemble s'appelle un _simulateur_.

=== Inventaire des simulateurs en robotique 

==== Isaac

Un simulateur développé par NVIDIA @isaacsim, utilisant son propre moteur de rendu, PhysX @physx

==== MuJoCo

Un simulateur initialement propriétaire. Il a été rendu gratuit puis open source par Google DeepMind @mujoco.

Bien que MuJoCo est décrit comme un moteur de simulation physique et non un simulateur, il embarque une commande `simulate` qui le rend fonctionnellement équivalent à un simulateur @mujoco-simulate.

==== Gazebo 

Les intérêts de Gazebo @gazebo sont multiples:

- C'est un logiciel open-source _communautaire_, qui ne dépend pas du financement d'une grande entreprise
- Son architecture modulaire permet notamment d'utiliser plusieurs moteurs de simulation physique différents @gazebo-physics-engines, à l'inverse de MuJoCo.

Gazebo possède des plugins officiels pour:

/ DART: Plugin `gz-physics-dartsim-plugin`, c'est l'implémentation principale, et celle par défaut @gazebo-physics-engines.
/ Bullet: Plugin `gz-physics-bulletsim-plugin`. En beta @gazebo-physics-engines.
/ Bullet Featherstone: Plugin `gz-physics-bullet-featherstone-plugin`, également en beta @gazebo-physics-engines.



=== Inventaire des moteurs de simulation physique 

==== DART

DART, pour Dynamic Animation and Robotics Toolkit @dart, 

==== Bullet

Bullet @bullet @pybullet

==== Bullet avec Featherstone

L'algorithme de Featherstone @featherstone, servant d'implémentation alternative à Bullet  @bullet-featherstone

=== Fonctions coût 

=== Descente de gradient


==== _Deep Q-Network_



==== _Trust Region Policy Optimization_

==== _Proximal Policy Optimization_




== Le H1v2 d'_Unitree_

== Reproductibilité logicielle
