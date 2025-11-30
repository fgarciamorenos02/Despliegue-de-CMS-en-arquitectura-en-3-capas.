# Despliegue de CMS en Arquitectura de 3 Capas

**CMS WordPress en Alta Disponibilidad y Escalable en AWS**

## Descripción General

Este proyecto detalla el proceso de despliegue de un sitio web WordPress en AWS utilizando una arquitectura de tres capas. La infraestructura está diseñada para asegurar alta disponibilidad y escalabilidad, siguiendo principios de seguridad y segmentación de red. A continuación, se describen los detalles técnicos y los scripts de aprovisionamiento utilizados.

## Requisitos

- **Acceso a AWS**: Cuenta activa de AWS.
- **CLI de AWS**: Configurada con las credenciales adecuadas.
- **Dominio Público**: Dominio registrado y apuntando a una IP elástica.
- **Permisos**: Acceso SSH a las instancias EC2.

### Dependencias

- **Sistema Operativo**: Linux (Ubuntu 20.04 o similar) en las instancias EC2.
- **Software Necesario**: Apache, PHP, NFS y MySQL/MariaDB.

## Estructura del Proyecto

La estructura del proyecto es la siguiente:

```
├── balanceador.sh      # Script para configurar el balanceador de carga.
├── nfs.sh              # Script para configurar el servidor NFS y contenido de WordPress.
├── webservers.sh       # Script para configurar los servidores backend.
├── sgbd.sh             # Script para configurar la base de datos.
└── README.md           # Documento técnico y explicativo.
```
# Arquitectura de Red en AWS

La infraestructura está basada en un modelo de **tres capas**, diseñado para asegurar seguridad, escalabilidad y alta disponibilidad en un entorno WordPress desplegado en AWS.

---

## Capa 1: Balanceador de Carga (Pública)

- Instancia **EC2** con **Apache** configurado como balanceador de carga.
- Acceso permitido únicamente desde Internet por los puertos:
  - **80** (HTTP)
  - **443** (HTTPS)
- Se encarga de distribuir el tráfico hacia los servidores backend.

---

## Capa 2: Servidores Backend + NFS (Privada)

- Dos instancias **EC2** funcionando como servidores backend donde se ejecuta WordPress.
- Un servidor **NFS** encargado de:
  - Compartir los archivos del sitio WordPress.
  - Mantener el contenido sincronizado entre los servidores web.

---

## Capa 3: Base de Datos (Privada)

- Instancia **EC2** con **MySQL/MariaDB**.
- Solo acepta conexiones provenientes de los servidores backend.
- Aloja la base de datos utilizada por WordPress.

---

## Scripts de Aprovisionamiento

Cada script implementa la instalación y configuración necesaria para cada componente de la arquitectura:

- Configuración del **balanceador de carga**.
- Instalación y puesta en marcha del **servidor NFS**.
- Preparación de los **servidores backend**.
- Configuración del **gestor de base de datos**.

---


