== 2-6 Juin

- Début de recherches sur l'installation de NixOS sur Raspberry Pi @raspi 400 et 5
- Flash du firmware master-board sur un testbench
- Test du packaging de odri_control_interface @odri-controls avec les scripts de démos à l'aide d'un testbench
- Début de recherches sur la création d'un plugin Gazebo @gazebo communiquant avec la couche bas niveau du SDK2 @unitree_sdk2 d'Unitree afin de simuler du code pour le robot H1 @h1 dans Gazebo

== 9-13 Juin

- Progrès sur l'accès à la couche bas niveau du SDK2 @unitree_sdk2
  - Analyse via Wireshark des paquets
  - Analyse du code source du plugin Mujoco @mujoco fourni par Unitree

== 16-20 Juin

- Réussite de l'accès à la couche bas niveau du SDK2 via les définitions IDL @omgidl fournies par Unitree
- Documentation sur le système de plugins de Gazebo @gazebo
- Début de travail sur le bridge Gazebo/unitree: `gz-unitree`
  - Implémentation de la communication DDS @dds entre un binaire d'exemple d'utilisation du SDK2 et le plugin Gazebo

== 23-27 Juin

- Construction du _lowstate_ à envoyer au SDK2 depuis _gz-unitree_:
- Utilisation du modèle SDF @sdf du robot H1-2 @h1v2 au lieu de H1 @h1, ajout d'un sol au monde du SDF
