# Despliegue de CMS en Arquitectura de 3 Capas
---

## Descripción General

Este proyecto detalla el despliegue de un sitio WordPress en AWS utilizando una arquitectura de tres capas. La infraestructura asegura **alta disponibilidad y escalabilidad**, siguiendo principios de seguridad y segmentación de red.

Se incluyen los detalles técnicos y los scripts de aprovisionamiento para cada capa.

---

## Requisitos

* **Cuenta de AWS** activa.
* **AWS CLI** configurada con credenciales.
* **Dominio público** apuntando a una IP elástica.
* **Acceso SSH** a las instancias EC2.

### Dependencias

* **SO**: Linux (Ubuntu 22.04 o similar)
* **Software**: Apache, PHP, NFS, MySQL/MariaDB

---

## Estructura del Proyecto

```
├── balanceador.sh      # Script para configurar el balanceador de carga
├── nfs.sh              # Script para configurar NFS y contenido de WordPress
├── webservers.sh       # Script para configurar servidores backend
├── sgbd.sh             # Script para configurar la base de datos
└── README.md           # Documentación técnica
```

---

# Arquitectura de Red en AWS

La arquitectura se basa en **tres capas**, con enfoque en seguridad, escalabilidad y alta disponibilidad:

1. **Capa 1:** Balanceador de carga (pública)
2. **Capa 2:** Servidores backend + NFS (privada)
3. **Capa 3:** Base de datos (privada)

---

## Capa 1: Balanceador de Carga (Pública)

* Instancia **EC2** con **Apache** configurado como balanceador.
* Acceso desde Internet únicamente por los puertos:

  * **80** (HTTP)
  * **443** (HTTPS)
* Distribuye el tráfico hacia los servidores backend.

### Bloques de configuración del balanceador

#### 🟦 Bloque 1: Instalación de Apache y módulos necesarios

```bash
sudo apt update
sudo apt install apache2 -y
sudo a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests proxy_connect ssl headers
sudo systemctl restart apache2
```

* Instala Apache y módulos necesarios para **proxy inverso, balanceo, SSL y sticky sessions**.
* Reinicia Apache para aplicar cambios.

---

#### 🟩 Bloque 2: Copia de configuración base

```bash
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/load-balancer.conf
```

* Crea una copia de la configuración por defecto para personalizar el balanceador.

---

#### 🟦 Bloque 3: Configuración HTTP → redirección a HTTPS

```bash
sudo tee /etc/apache2/sites-available/load-balancer.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName wordpressfabiogms.ddns.net
    ServerAdmin webmaster@localhost
    Redirect permanent / https://wordpressfabiogms.ddns.net/
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
```

* Redirige todo el tráfico HTTP a HTTPS (**301 permanente**).

---

#### 🟫 Bloque 4: Configuración HTTPS + Balanceo de carga

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
        BalancerMember http://192.168.30.20:80 route=1
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

* Configura VirtualHost **HTTPS (443)** con certificados Let’s Encrypt.
* Crea clúster de balanceo `mycluster` con dos servidores backend.
* Habilita **sticky sessions** y redirige tráfico mediante `ProxyPass`.

---

#### 🟥 Bloque 5: Desactivar sitio por defecto

```bash
sudo a2dissite 000-default.conf
```

* Evita conflictos desactivando la configuración por defecto de Apache.

---

#### 🟧 Bloque 6: Activar configuración del balanceador

```bash
sudo a2ensite load-balancer.conf
sudo a2ensite load-balancer-ssl.conf
```

* Activa los VirtualHost personalizados para HTTP y HTTPS.

---

#### 🟦 Bloque 7: Recargar Apache

```bash
sudo systemctl reload apache2
```

* Aplica todos los cambios sin reiniciar Apache.

---

### ⚪ Opcional: Configurar SSL con Certbot

```bash
sudo apt update
sudo apt install certbot python3-certbot-apache -y
sudo certbot --apache -d wordpressfabiogms.ddns.net --agree-tos --email fgarciamorenos02@iesalbarregas.es -n
```


* Instala **Certbot** y el plugin de Apache.
* Obtiene y configura automáticamente un certificado SSL para el dominio.
---

## Capa 2: Servidores Backend + NFS (Privada)

* Dos instancias **EC2** ejecutando WordPress.
* Un servidor **NFS** para compartir archivos entre los servidores backend.

---

### Bloques de configuración de los servidores web

#### 🟦 Bloque 1: Instalación de paquetes necesarios

```bash
sudo apt update
sudo apt install nfs-common apache2 php libapache2-mod-php php-mysql php-curl php-gd php-xml php-mbstring php-xmlrpc php-zip php-soap php-intl -y
```

* Apache, PHP y extensiones para WordPress.
* Cliente NFS (`nfs-common`) para montar directorios compartidos.

---

#### 🟩 Bloque 2: Crear directorio local para NFS

```bash
sudo mkdir -p /nfs/general
```

* Directorio donde se montará el recurso NFS compartido.

---

#### 🟦 Bloque 3: Montaje del NFS compartido

```bash
sudo mount 192.168.30.23:/var/nfs/general /nfs/general
```

* Monta directorio NFS remoto en `/nfs/general`.

---

#### 🟫 Bloque 4: Configurar montaje automático en arranque

```bash
echo "192.168.30.23:/var/nfs/general  /nfs/general  nfs _netdev,auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | sudo tee -a /etc/fstab
```

* Garantiza que NFS se monte automáticamente al iniciar la instancia.

---

#### 🟧 Bloque 5: Configurar VirtualHost Apache para WordPress

```bash
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/wordpress.conf
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

* `DocumentRoot` apunta al NFS compartido.
* Habilita `.htaccess` y enlaces simbólicos.
* Configura logs de Apache.

---

#### 🟥 Bloque 6: Activar VirtualHost y desactivar por defecto

```bash
sudo a2dissite 000-default.conf
sudo /usr/sbin/a2ensite wordpress.conf
sudo systemctl reload apache2
```

* Activa WordPress y aplica los cambios.

---

### Bloques de configuración del servidor NFS

#### 🟦 Bloque 1: Instalar NFS

```bash
sudo apt update
sudo apt install nfs-kernel-server -y
```

**Comentario:**

* Actualiza la lista de paquetes del sistema.
* Instala el **servidor NFS** (`nfs-kernel-server`) que permitirá compartir directorios con los servidores backend.

---

#### 🟩 Bloque 2: Crear directorio compartido y permisos

```bash
sudo mkdir -p /var/nfs/general
sudo chown nobody:nogroup /var/nfs/general
```

**Comentario:**

* Crea el directorio `/var/nfs/general` que se compartirá vía NFS.
* Asigna como propietario a `nobody:nogroup`, práctica estándar en NFS para acceso seguro y sin conflictos de permisos.

---

#### 🟦 Bloque 3: Configurar exportaciones NFS

```bash
echo "/var/nfs/general 192.168.30.20(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
echo "/var/nfs/general 192.168.30.24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
```


* Permite que las instancias backend (`192.168.30.20` y `192.168.30.24`) monten el directorio NFS.
* Opciones explicadas:

  * `rw`: lectura y escritura
  * `sync`: escritura sincrónica para mayor seguridad de datos
  * `no_subtree_check`: evita errores al mover archivos dentro del directorio compartido

---

#### 🟫 Bloque 4: Descargar y descomprimir WordPress

```bash
sudo apt install unzip -y
sudo wget -O /var/nfs/general/latest.zip https://wordpress.org/latest.zip
sudo unzip /var/nfs/general/latest.zip -d /var/nfs/general/
```


* Instala `unzip` para descomprimir archivos.
* Descarga la última versión de WordPress desde el sitio oficial.
* Descomprime WordPress directamente en el directorio compartido NFS para que todos los backend accedan al mismo contenido.

---

#### 🟧 Bloque 5: Asignar permisos correctos

```bash
sudo chown -R www-data:www-data /var/nfs/general/wordpress
sudo find /var/nfs/general/wordpress/ -type d -exec chmod 755 {} \;
sudo find /var/nfs/general/wordpress/ -type f -exec chmod 644 {} \;
```


* Cambia el propietario de los archivos y directorios a `www-data` (usuario de Apache).
* Permisos:

  * Directorios: `755` (lectura y ejecución para todos, escritura solo para propietario)
  * Archivos: `644` (lectura para todos, escritura solo para propietario)
* Garantiza que WordPress funcione correctamente y sea seguro.

---

#### 🟦 Bloque 6: Reiniciar NFS y exportar

```bash
sudo systemctl restart nfs-kernel-server
sudo exportfs -a
```


* Reinicia el servicio NFS para aplicar cualquier cambio.
* `exportfs -a` exporta todos los directorios configurados en `/etc/exports`, haciéndolos accesibles a los servidores backend.

---

## Capa 3: Base de Datos (Privada)

* Instancia **EC2** con MySQL/MariaDB.
* Solo accesible desde los servidores backend.
* Aloja la base de datos de WordPress.

### Bloques de configuración de la base de datos

#### 🟦 Bloque 1: Instalar MySQL Server

```bash
sudo apt update
sudo apt install mysql-server -y
```

* Actualiza la lista de paquetes disponibles.
* Instala MySQL Server en la instancia EC2, necesario para alojar la base de datos de WordPress.

---

#### 🟩 Bloque 2: Crear base de datos

```bash
sudo mysql -e "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
```

* Crea la base de datos llamada `wordpress`.
* Usa codificación UTF-8 (`utf8`) para soportar caracteres especiales y acentos.
* Collation `utf8_unicode_ci` permite comparaciones correctas de texto internacional.

---

#### 🟦 Bloque 3: Crear usuarios backend

```bash
sudo mysql -e "CREATE USER 'UsuarioWordPress'@'192.168.30.20' IDENTIFIED BY '1234';"
sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'UsuarioWordPress'@'192.168.30.20';"

sudo mysql -e "CREATE USER 'UsuarioWordPress'@'192.168.30.24' IDENTIFIED BY '1234';"
sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'UsuarioWordPress'@'192.168.30.24';"
```

* Crea un usuario MySQL `UsuarioWordPress` para cada servidor backend.
* Asigna **todos los privilegios** sobre la base de datos `wordpress` (lectura, escritura, modificación, borrado).
* Limita la conexión a la IP privada de cada servidor backend (`192.168.30.20` y `192.168.30.24`) para mayor seguridad.

---

#### 🟫 Bloque 4: Aplicar cambios de privilegios

```bash
sudo mysql -e "FLUSH PRIVILEGES;"
```

* Aplica los cambios realizados en los privilegios sin necesidad de reiniciar MySQL.
* Garantiza que los nuevos usuarios y permisos estén activos inmediatamente.

---

#### 🟧 Bloque 5: Configurar MySQL para conexiones internas

```bash
sudo sed -i 's/^bind-address[[:space:]]*=.*/bind-address = 192.168.30.45/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql
```

---

# 🛠️ Configuración de Red en AWS

---

## 1. **Crear una VPC personalizada**

- Ve al servicio **VPC** y selecciona **Crear VPC**.  
- Elige la opción **VPC con subredes públicas y privadas**.  
- Define el bloque CIDR para la red; por ejemplo, puedes usar **10.0.0.0/16** o, en este caso, **192.168.30.0/24**.

---

## 2. **Configurar subredes**

### **Subred pública**
Crea una subred pública destinada al balanceador de carga.  
Rango utilizado: **192.168.30.0/28**.

### **Subredes privadas**

- **Red interna 1:** destinada a los servidores web y al servidor NFS.  
  Rango utilizado: **192.168.30.16/28**.

- **Red interna 2:** destinada a la base de datos.  
  Rango utilizado: **192.168.30.32/28**.

---

## 3. **Configurar el Internet Gateway**

- Crea un **Internet Gateway** y asígnalo a la VPC para permitir el acceso a Internet desde la subred pública.

---

## 4. **Configurar las Tablas de Enrutamiento**

### **Tabla de enrutamiento pública**
Asocia la subred pública a una tabla de rutas que incluya una salida hacia el **Internet Gateway**, de modo que permita el acceso a Internet. *(rutas públicas)*

### **Tabla de enrutamiento privada**
Vincula las subredes privadas a una tabla de rutas privada que tenga una salida hacia el **NAT Gateway**, permitiendo que los recursos internos realicen conexiones hacia el exterior sin ser accesibles desde Internet.

---

## 5. **Crear Grupos de Seguridad**

### **Balanceador de carga**
Configura un grupo de seguridad que permita:  
- Tráfico **HTTP (80)** y **HTTPS (443)** desde cualquier origen.  
- Acceso **SSH (22)** desde cualquier ubicación si es necesario para administración.  
*(reglas de entrada para el balanceador)*

### **Servidores Backend (Webservers)**
Crea un grupo de seguridad que acepte:  
- Tráfico **HTTP (80)** únicamente desde el grupo de seguridad del balanceador de carga.  
- Acceso al servicio **NFS (2049)** desde el servidor NFS.  
*(reglas de entrada para los webservers)*

### **Servidor NFS**
Define un grupo de seguridad que permita:  
- Conexiones **NFS (2049)** únicamente desde los servidores backend.  
*(reglas de entrada para NFS)*

### **Base de Datos**
Configura un grupo de seguridad que acepte:  
- Conexiones **MySQL (3306)** exclusivamente desde los servidores backend.

---

## 6. **Crear Instancias EC2**

### **Balanceador de carga**
Lanza la instancia correspondiente (o el servicio que actúe como balanceador) dentro de la **subred pública**.

### **Servidores Web y NFS**
Despliega tanto los **web servers** como el **servidor NFS** en la **subred privada 1**.

### **Base de datos**
Crea la instancia destinada a la **base de datos** dentro de la **subred privada 2**.

---

## 7. **Asignar una IP Elástica al Balanceador**

- Reserva una **IP Elástica (EIP)** desde el panel de EC2.  
- Asígnala a la instancia que funcionará como **balanceador de carga**, asegurando que tenga una dirección pública fija para el acceso externo.

---
