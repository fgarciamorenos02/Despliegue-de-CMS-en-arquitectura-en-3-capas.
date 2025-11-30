# === PASO 1: INSTALACIÓN Y MÓDULOS ESENCIALES ===

# Instalamos Apache y módulos de balanceo/proxy/SSL.
sudo apt update
sudo apt install apache2 -y
sudo a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests proxy_connect ssl headers

# Reiniciar servicio apache para cargar todos los módulos.
sudo systemctl restart apache2

# === PASO 2: CONFIGURACIÓN HTTP (PUERTO 80) PARA REDIRECCIÓN ===

# Copiamos el Fichero de config.
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/load-balancer.conf

# Sobrescribimos el fichero HTTP para REDIRECCIÓN FORZADA a HTTPS.
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

# === PASO 3: CONFIGURACIÓN HTTPS (PUERTO 443 con Terminación SSL) ===

# Sobrescribimos el archivo SSL para el Balanceo de Carga.
sudo tee /etc/apache2/sites-available/load-balancer-ssl.conf > /dev/null <<EOF
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    ServerName wordpressfabiogms.ddns.net
    SSLEngine On
    SSLCertificateFile /etc/letsencrypt/live/wordpressfabiogms.ddns.net/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/wordpressfabiogms.ddns.net/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    # 2. CONFIGURACIÓN DEL BALANCEO
    <Proxy balancer://mycluster>
        ProxySet stickysession=JSESSIONID|ROUTEID
        
        # Servidor Web 1
        BalancerMember http://192.168.30.20:80 route=1
        
        # Servidor Web 2
        BalancerMember http://192.168.30.24:80 route=2
    </Proxy>

    # Reenvía todas las peticiones al grupo de balanceo
    ProxyPass / balancer://mycluster/
    ProxyPassReverse / balancer://mycluster/

    ErrorLog \${APACHE_LOG_DIR}/ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/ssl_access.log combined

</VirtualHost>
</IfModule>
EOF

# === PASO 4: HABILITAR SITIOS Y APLICAR CAMBIOS ===

# Deshabilitamos el sitio por defecto.
sudo a2dissite 000-default.conf

# Habilitamos la configuración HTTP y HTTPS.
sudo a2ensite load-balancer.conf
sudo a2ensite load-balancer-ssl.conf

# Finalmente, aplicamos todos los cambios.
sudo systemctl reload apache2