# Instalamos MySQL
sudo apt update
sudo apt install mysql-server -y

# Creamos la base de datos de WordPress.
sudo mysql -e "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

# Creamos el usuario y otorgamos privilegios al Servidor Web 1 (192.168.30.20)
sudo mysql -e "CREATE USER 'UsuarioWordPress'@'192.168.30.20' IDENTIFIED BY '1234';"
sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'UsuarioWordPress'@'192.168.30.20';"

# Creamos el usuario y otorgamos privilegios al Servidor Web 2 (192.168.30.24)
sudo mysql -e "CREATE USER 'UsuarioWordPress'@'192.168.30.24' IDENTIFIED BY '1234';"
sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'UsuarioWordPress'@'192.168.30.24';"

# Aplicamos los cambios de privilegios
sudo mysql -e "FLUSH PRIVILEGES;"

# Configuramos el Bind Adress del MySQL (192.168.30.45) para permitir conexiones remotas.
sudo sed -i 's/^bind-address[[:space:]]*=.*/bind-address = 192.168.30.45/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql