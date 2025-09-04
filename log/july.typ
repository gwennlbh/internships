== 30 Juin - 4 Juillet

- Continuation du travail: essais pour rajouter un capteur IMU sur le robot, essais pour faire fonctionner l'auto-collision

== 7-11 Juillet

- Capteur IMU rajouté
- Ajout du tick (temps) de simulation 
- Essais d'utilisation de gz-unitree avec les politiques RL#footnote[Reinforcement Learning] de Gepetto

== 14-18 Juillet

- Tentatives d'amélioration des performances pour améliorer le RTF: passage de 10% à 15%
  - Parallélisation de l'envoi des messages des DDS dans un thread différent du principal
  - Optimisations classiques

- Ecriture d'une recette _Just_ @justfile pour configurer l'environnement de développement, sur Arch Linux ou Ubuntu
- Reproduction des résultats sur un OS et une machine différente

== 21-25 Juillet

- Évaluation de `gazebo-sim-overlay` @gazebo-sim-overlay comme solution pour un packaging Nix
- Recherche sur un mode headless de gazebo suite à des erreurs de QT sous devshell Nix

== 28 Juillet - 1 août

- Recherche autour de l'utilisation de Gazebo dans des environnements CI/CD @msr2022-cps, en particulier pour capturer une simulation en vidéo
