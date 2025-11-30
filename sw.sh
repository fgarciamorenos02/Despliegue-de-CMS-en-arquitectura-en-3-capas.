# === PARTE 1: NFS y PHP ===

# Instalamos cliente de NFS y módulos PHP esenciales.
sudo apt update
sudo apt install nfs-common apache2 php libapache2-mod-php php-mysql php-curl php-gd php-xml php-mbstring php-xmlrpc php-zip php-soap php-intl -y

# Creamos la carpeta de montaje.
sudo mkdir -p /nfs/general

# Montamos la carpeta del Servidor NFS (192.168.30.23).
sudo mount 192.168.30.23:/var/nfs/general /nfs/general

# Automatizamos el montado.
echo "192.168.30.23:/var/nfs/general  /nfs/general  nfs _netdev,auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | sudo tee -a /etc/fstab

# === PARTE 2: CONFIGURACIÓN DE VIRTUAL HOST ===

# Copiamos y nombramos el fichero de config.
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/wordpress.conf

# Configuración para servir el contenido desde NFS.
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

# Deshabilitamos el que esta por defecto y habilitamos el creado.
sudo a2dissite 000-default.conf
sudo /usr/sbin/a2ensite wordpress.conf

# Reiniciamos apache.
sudo systemctl reload apache2