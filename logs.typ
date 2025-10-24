#import "template.typ": arkheion, arkheion-appendices
#show: arkheion.with(
  title: "Stage au LAAS",
  authors: (
    (
      name: "Gwenn Le Bihan",
      email: "gwenn.lebihan@etu.inp-n7.fr",
      affiliation: "ENSEEIHT",
    ),
  ),
  date: datetime.today(),
  logo: "enseeiht.jpeg",
  abstract: [
    Ce stage porte sur l'intégration de Nix et NixOS dans les processus de développement et de déploiement logiciel dans le domaine robotique au sein du LAAS. Nix, le _package manager_, et NixOS, l'OS, sont des technologies permettant une reproductibilité, une qualité importante dans le monde de la recherche.

    J'ai été aussi amenée à travailler sur la création d'un _plugin_ pour Gazebo, un logiciel de simulation robotique, pour l'utiliser avec le _SDK_ d'un robot de Unitree.
  ],
)

#outline(
  title: [Table des matières],
)

#pagebreak()


#include "biblio.typ"

= Journal de bord

#for month in ("may", "june", "july", "august", "september", "november") {
  include ("log/" + month + ".typ")
}

#bibliography("bib.yaml")
