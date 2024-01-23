#!/bin/bash

# Fonction pour installer un package s'il n'est pas déjà installé
install_package() {
  package_name=$1
  if ! dpkg -l | grep -q "$package_name"; then
    sudo apt-get install -y "$package_name"
  else
    echo "Package '$package_name' is already installed"
  fi
}

# Installer ou mettre à jour python3 et python3-pip
install_package "python3"
install_package "python3-pip"

# Installer ou mettre à jour docker et docker-compose
install_package "docker"
install_package "docker-compose"

# Vérifier si virtualenv est installé, sinon, l'installer
if ! command -v virtualenv &> /dev/null; then
  install_package "python3-venv"  # Pour les systèmes basés sur Ubuntu/Debian
  # OU
  # install_package "python3-virtualenv"  # Pour d'autres systèmes
fi

# Créer un environnement virtuel
python3 -m venv venv

# Activer l'environnement virtuel
source venv/bin/activate   # Sur Linux ou macOS
# OU
# venv\Scripts\activate       # Sur Windows

# Installer kafka-python dans l'environnement virtuel
pip install kafka-python

# Cloner le référentiel kafka-docker s'il n'existe pas
if [ ! -d "kafka-docker" ]; then
  sudo git clone https://github.com/wurstmeister/kafka-docker.git
else
  echo "Kafka-docker repository already exists"
fi

# Aller dans le répertoire kafka-docker
cd kafka-docker/

# Créer le fichier docker-compose.yml
filename="docker-compose-expose.yml"
cat << EOF > $filename
version: '2'
services:
  zookeeper:
    image: wurstmeister/zookeeper:3.4.6
    ports:
     - "2181:2181"
  kafka:
    build: .
    ports:
     - "9092:9092"
    expose:
     - "9093"
    environment:
      KAFKA_ADVERTISED_LISTENERS: INSIDE://kafka:9093,OUTSIDE://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT
      KAFKA_LISTENERS: INSIDE://0.0.0.0:9093,OUTSIDE://0.0.0.0:9092
      KAFKA_INTER_BROKER_LISTENER_NAME: INSIDE
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_CREATE_TOPICS: "topic_test:1:1"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo "YAML file $filename has been created."

# Démarrer les conteneurs Docker
sudo docker-compose -f $filename up

# Désactiver l'environnement virtuel lorsque vous avez terminé
deactivate

