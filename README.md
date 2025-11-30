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

## 🟦 Bloque 1: Instalación de Apache y módulos necesarios

```bash
sudo apt update
sudo apt install apache2 -y
sudo a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests proxy_connect ssl headers

sudo systemctl restart apache2
````

Este bloque instala Apache y activa los módulos necesarios para permitir:

* Proxy inverso
* Balanceo de carga
* Conexiones SSL
* Métodos de balanceo por peticiones

Después reinicia Apache para cargar correctamente todos los módulos.

---

## 🟩 Bloque 2: Copia del archivo base de configuración

```bash
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/load-balancer.conf
```

Copia la configuración por defecto de Apache y la renombra para trabajar sobre una configuración personalizada del balanceador.

---

## 🟦 Bloque 3: Configuración HTTP con redirección a HTTPS

```bash
sudo tee /etc/apache2/sites-available/load-balancer.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName wordpressfabiogms.ddns.net
    ServerAdmin webmaster@localhost
    
    # Redirección permanente: Envía todo el tráfico HTTP a HTTPS
    Redirect permanent / https://wordpressfabiogms.ddns.net/

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
```

Este bloque crea el VirtualHost para el puerto **80**, cuya única función es:

* Redirigir todo el tráfico HTTP a HTTPS mediante redirección **301 permanente**

Así se obliga a los usuarios a conectarse siempre mediante una conexión segura.

---

## 🟫 Bloque 4: Configuración HTTPS + Balanceo de carga

```bash
sudo tee /etc/apache2/sites-available/load-balancer-ssl.conf > /dev/null <<EOF
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    ServerName wordpressfabiogms.ddns.net
    SSLEngine On
    SSLCertificateFile /etc/letsencrypt/live/wordpressfabiogms.ddns.net/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/wordpressfabiogms.ddns.net/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    <Proxy balancer://mycluster>
        ProxySet stickysession=JSESSIONID|ROUTEID
        
        # Servidor Web 1
        BalancerMember http://192.168.30.20:80 route=1
        
        # Servidor Web 2
        BalancerMember http://192.168.30.24:80 route=2
    </Proxy>

    ProxyPass / balancer://mycluster/
    ProxyPassReverse / balancer://mycluster/

    ErrorLog \${APACHE_LOG_DIR}/ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/ssl_access.log combined

</VirtualHost>
</IfModule>
EOF
```

Este bloque configura el VirtualHost para **HTTPS (443)** con SSL, usando certificados de Let’s Encrypt. También:

* Crea un clúster de balanceo `mycluster`
* Añade dos servidores backend con rutas distintas
* Habilita **sticky sessions**
* Redirige todas las peticiones entrantes hacia los servidores backend usando `ProxyPass`

---

## 🟥 Bloque 5: Desactivar el sitio por defecto

```bash
sudo a2dissite 000-default.conf
```

Desactiva la configuración por defecto de Apache, evitando conflictos con la configuración del balanceador.

---

## 🟧 Bloque 6: Activar las configuraciones del balanceador

```bash
sudo a2ensite load-balancer.conf
sudo a2ensite load-balancer-ssl.conf
```

Activa los sitios de configuración HTTP y HTTPS del balanceador.

---

## 🟦 Bloque 7: Recargar Apache

```bash
sudo systemctl reload apache2
```

Recarga Apache para aplicar todos los cambios sin necesidad de detener el servicio.

---

## Capa 2: Servidores Backend + NFS (Privada)

- Dos instancias **EC2** funcionando como servidores backend donde se ejecuta WordPress.
- Un servidor **NFS** encargado de:
  - Compartir los archivos del sitio WordPress.
  - Mantener el contenido sincronizado entre los servidores web.
 
## 🟦 Bloque 1: Instalación de paquetes necesarios

```bash
sudo apt update
sudo apt install nfs-common apache2 php libapache2-mod-php php-mysql php-curl php-gd php-xml php-mbstring php-xmlrpc php-zip php-soap php-intl -y
````

Este bloque instala:

* Apache2 como servidor web.
* PHP y extensiones necesarias para WordPress.
* Cliente NFS (`nfs-common`) para montar sistemas de archivos compartidos.

---

## 🟩 Bloque 2: Creación del directorio NFS local

```bash
sudo mkdir -p /nfs/general
```

Crea el directorio donde se montará el recurso NFS compartido.

---

## 🟦 Bloque 3: Montaje del NFS compartido

```bash
sudo mount 192.168.30.23:/var/nfs/general /nfs/general
```

Monta el directorio NFS remoto (`192.168.30.23:/var/nfs/general`) en el directorio local `/nfs/general`.
Esto permite que múltiples servidores web compartan los mismos archivos de WordPress.

---

## 🟫 Bloque 4: Configuración del montaje automático

```bash
echo "192.168.30.23:/var/nfs/general  /nfs/general  nfs _netdev,auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | sudo tee -a /etc/fstab
```

Agrega el NFS al archivo `/etc/fstab` para que se monte automáticamente al iniciar el sistema.
Opciones usadas:

* `_netdev`: esperar a que la red esté disponible
* `auto`: montar al arranque
* `nofail`: no fallar si no está disponible
* `noatime`, `nolock`, `intr`, `tcp`, `actimeo=1800`: optimización y confiabilidad

---

## 🟧 Bloque 5: Copia de la configuración de Apache para WordPress

```bash
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/wordpress.conf
```

Copia la configuración por defecto de Apache para crear un VirtualHost específico para WordPress.

---

## 🟦 Bloque 6: Configuración del VirtualHost para WordPress

```bash
sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName wordpressfabiogms.ddns.net
    ServerAdmin webmaster@localhost
    DocumentRoot /nfs/general/wordpress/
    
    <Directory /nfs/general/wordpress>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
```

Define un VirtualHost en el puerto **80** para WordPress:

* `DocumentRoot` apunta al directorio NFS compartido.
* `AllowOverride All` permite usar `.htaccess`.
* `Options +FollowSymlinks` habilita enlaces simbólicos.
* Logs separados de Apache (`error.log` y `access.log`).

---

## 🟥 Bloque 7: Desactivar el sitio por defecto y activar WordPress

```bash
sudo a2dissite 000-default.conf
sudo /usr/sbin/a2ensite wordpress.conf
```

* Desactiva la configuración por defecto de Apache.
* Activa el VirtualHost para WordPress.

---

## 🟦 Bloque 8: Recargar Apache

```bash
sudo systemctl reload apache2
```

Aplica todos los cambios realizados sin reiniciar el servicio.

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


