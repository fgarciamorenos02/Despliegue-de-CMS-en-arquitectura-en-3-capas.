# Instalamos el servidor NFS.
sudo apt update
sudo apt install nfs-kernel-server -y

# Creamos y configuramos el directorio que queremos compartir.
sudo mkdir -p /var/nfs/general
sudo chown nobody:nogroup /var/nfs/general

# Añadimos a los servidores web como clientes (192.168.30.20 y 192.168.30.24).
echo "/var/nfs/general 192.168.30.20(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
echo "/var/nfs/general 192.168.30.24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports

# Descargamos e instalamos WordPress.
sudo apt install unzip -y
sudo wget -O /var/nfs/general/latest.zip https://wordpress.org/latest.zip
sudo unzip /var/nfs/general/latest.zip -d /var/nfs/general/

# Cambiamos el propietario para Apache y establecemos permisos estándar.
sudo chown -R www-data:www-data /var/nfs/general/wordpress
sudo find /var/nfs/general/wordpress/ -type d -exec chmod 755 {} \;
sudo find /var/nfs/general/wordpress/ -type f -exec chmod 644 {} \;

# Reiniciamos el servidor NFS.
sudo systemctl restart nfs-kernel-server
sudo exportfs -a