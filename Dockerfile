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

# Configuración de políticas de contraseñas seguras y prevención de ataques de fuerza bruta
#
# Para la gestión de contraseñas se va a incluir el módulo pwquality para establecer
# la fortaleza de las mismas.
#
# Una vez establecidas las políticas de contraseñas seguras, se establecen las politicas
# de caducidad de las mismas para obligar a los usuarios a mantenerlas actualizadas y de 
# paso establecer una politica para eliminar las cuentas zombies que se crean de forma
# temporal y se olvida de borrarlas.
#
# Por último, vamos a integrar un mecanismo de bloqueo automático de cuentas cuando
# se realicen numerosos intentos de inicio de sesión erróneos consecutivos, con el
# fin de evitar el acceso a las cuentas mediante ataques de fuerza bruta. Para esta 
# configuración se usará el módulo pam_taly2 (otra alternativa sería pam_faillock).
# Vamos a configurar que el número máximo de intentos de inicio de sesión incorrectos
# consecutivos sea de 10, tras lo cual se procederá a bloquar la cuenta durante 10 minutos.
COPY ./setup/config_files/pwquality.conf /etc/security/pwquality.conf
COPY ./setup/config_files/login.defs /etc/login.defs
RUN echo "auth required pam_tally2.so deny=10 unlock_time=600" >> /etc/pam.d/common-auth

# Configuramos el antirootkit
COPY ./setup/config_files/rkhunter.conf /etc/rkhunter.conf

# Configuraciones servidor SSH
COPY ./setup/config_files/sshd_config /etc/ssh/sshd_config

# Borramos los scripts temporales
RUN rm -r /setup

# Lanzamos los servicios de nginx y ssh
CMD ["bash", "-c", "/etc/init.d/nginx start && /etc/init.d/ssh start && /etc/init.d/maldet start"]