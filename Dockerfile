FROM ubuntu:22.04
WORKDIR /

# Instalaciones necesarias
COPY ./setup/instalaciones /setup/instalaciones
RUN chmod +x setup/instalaciones
RUN /setup/instalaciones

# Copiamos todos los archivos del sitio web
COPY ./webpage/* /var/www/html

# Configuracionde las cuentas del sistema con políticas de mínimos privilegios
COPY ./setup/gestion_cuentas /setup/gestion_cuentas
RUN chmod +x setup/gestion_cuentas
RUN /setup/gestion_cuentas

# Configuración de políticas de contraseñas seguras y prevención de ataques de fuerza.
COPY ./setup/config_files/pwquality.conf /etc/security/pwquality.conf
COPY ./setup/config_files/login.defs /etc/login.defs
COPY ./setup/config_files/common-auth /etc/pam.d/common-auth
COPY ./setup/config_files/common-account /etc/pam.d/common-account
COPY ./setup/config_files/faillock.conf /etc/security/faillock.conf
# Los archivios se copian con más permisos de los necesarios, por tanto los reestablecemos
RUN chmod 644 /etc/pam.d/common-account /etc/pam.d/common-auth /etc/login.defs \
/etc/security/pwquality.conf /etc/security/faillock.conf

# Configuraciones actualizaciones de seguridad
COPY ./setup/config_files/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades


# Configuramos el antirootkit
COPY ./setup/config_files/rkhunter.conf /etc/rkhunter.conf

# Configuraciones servidor SSH
COPY ./setup/config_files/sshd_config /etc/ssh/sshd_config

# Configuramos los tips de seguridad
COPY ./setup/config_files/motd /etc/motd

# Cargamos y ejecutamos la configuración del firewall
COPY ./setup/gestion_firewall /setup/gestion_firewall
RUN chmod +x setup/gestion_cuentas
RUN /setup/gestion_cuentas

# Borramos los scripts temporales
RUN rm -r /setup


# Lanzamos los servicios de nginx y ssh
CMD ["bash", "-c", "/etc/init.d/nginx start && /etc/init.d/ssh start && /etc/init.d/maldet start"]