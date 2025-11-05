Il est désormais possible d'utiliser le simulateur modulaire, open-source et communautaire _Gazebo_ pour entraîner des politiques de reinforcement learning sur le robot _H1v2_ de la société Unitree.

Bien que la reproductibilité de compilation ne soit pas encore atteinte, l'utilisation du gestionnaire de paquets Nix semble possible pour obtenir des garanties de reproductibilité.

Les performances du _bridge_ SDK2 $arrows.lr$ Gazebo sont encore à améliorer, mais son utilisation est envisageable dans un contexte asynchrone, où le développement ne demande pas d'attendre les résultats de la simulation, via la pratique du CI/CD, par exemple.
