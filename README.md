# Spring Boot Kotlin Vault & Consul Example on Kubernetes

Spring Boot Kotlin Vault & Consul Example on Kubernetes

<img src="https://github.com/susimsek/spring-boot-vault-example/blob/master/images/introduction.png" alt="Spring Boot Kotlin Vault & Consul Example" width="100%" height="100%"/> 

# Vault

HashiCorp's Vault is a tool to store and secure secrets. Vault, in general, solves the software development security problem of how to manage secrets.

<img src="https://github.com/susimsek/spring-boot-vault-example/blob/master/images/vault.png" alt="Spring Boot Kotlin Vault" width="100%" height="100%"/>

# Consul

Consul is a tool that provides components for resolving some of the most common challenges in a micro-services architecture:

Service Discovery – to automatically register and unregister the network locations of service instances
Health Checking – to detect when a service instance is up and running
Distributed Configuration – to ensure all service instances use the same configuration

<img src="https://github.com/susimsek/spring-boot-vault-example/blob/master/images/consul.png" alt="Spring Boot Kotlin Consul" width="100%" height="100%"/>

# Development

Before you can build this project, you must install and configure the following dependencies on your machine.

## Prerequisites for App

* Java 17
* Maven 3.x
* Vault
* Consul
* Jq

### Run the app

You can run the spring boot app by typing the following command

```sh
mvn spring-boot:run
```

# Docker

The docker image  application can be built as follows:

```sh
mvn -Pjib verify jib:dockerBuild
```

## Deployment with Docker Compose

You can start app (accessible on http://localhost:8085) with

```sh
 ./deploy.sh -d
```

You can uninstall app the following bash command

```sh
 ./deploy.sh -d -r
```

## Deployment Kubernetes with Helm

You can deploy app by running the following bash command

```sh
 ./deploy.sh -k
```

You can uninstall app the following bash command

```sh
 ./deploy.sh -k -r
```

You can upgrade native reactive Graphql api (if you have made any changes to the generated manifests) by running the
following bash command

```sh
 ./deploy.sh -u
```

The Native Reactive Graphql API can be accessed with ingress from the link below.  
http://sb-vault-sample.susimsek.github.io

# Used Technologies

* Java 17
* Kotlin
* Spring Boot
* Spring Cloud
* Vault
* Consul
* Docker
* Kubernetes
* Helm
* Spring Web
* Spring Actuator
* Dev tools(dev environment)
