# Bastionado de servidor Web/SSH
Esta sección del proyecto se centra en la securización de un servidor web al que se puede acceder de forma remota. El bastionado de este nodo tan crítico de la red se realizará llevando a cabo una serie de pasos que se describen a continuación y que se desarrollan más adelante.
1. **Gestión de cuentas:** se crearán cuentas específicas para la administración del servidor web con privilegios limitados mediante políticas de sudo y ACLs. Se creará un usuario administrador y se deshabilitará la cuenta root, para evitar ataques de fuerza bruta sobre este conocido y sensible usuario.

2. **Políticas seguridad y caducidad de cuentas:** se establecerán políticas para obligar a los usuarios a crear contraseñas seguras. Además, se establecerán políticas de caducidad para que los usuarios deban cambiar las contraseñas con cierta frecuencia y evitar la proliferación de cuentas zombie que nadie usa, pero que permanecen activas en el sistema. Adicionalmente, se establecerá un mecanismo de bloqueo automático en cuentas que reciban un número exageradamente elevado de intentos de inicio de sesión inválidos, para evitar ataques de diccionario o de fuerza bruta.

3. **Análisis activo:** se instalarán y configurarán herramientas de análisis y tratamiento de malware y rootkits.

4. **Cifrado de discos:** se realizará un cifrado del disco para proteger el filtrado de datos en caso de que un atacante consiga acceso físico al servidor.

5. **Actualizaciones automáticas:** se configurará un servicio automatizado para la aplicación de parches de seguridad de forma automática para mantener el servidor lo más actualizado posible en todo momento.

6. **Copias de seguridad:** se configurará un mecanismo para la realización de copias de seguridad periódicas de los datos más importantes del servidor.

7. **Monitorización:** se llevará a cabo una minuciosa monitorización del estdo del sistema y de los logs emitidos por las distintas herramientas de detección de intrusiones y detección de malware y rootkits.

8. **Hardening SSH:** se alpicará una configuración segura de SSH mediante el cual se requerirá autenticación con clave pública/privada. Se cambiará el puerto por defecto para dificultar el escaneo por parte de servicios de escaneo masivos. Se configurarán politicas para evitar ataques de fuerza bruta en la autenticación por SSH. Se limitarán el número de conexiones simultáneas sobre el servidor para evitar la sobrecarga y posible caída del mismo. Se configurarán métodos de cifrado seguros y se deshabilitarán los considerados menos seguros.
---
## 1. Gestión de cuentas
En esta sección se va a configurar un nueva cuenta de administrador, con privilegios de sudo para realizar cualquier acción en el sistema. Al mismo tiempo se deshabilitará la cuenta root. La motivación de esto son múltiples:
- La cuenta root es muy conocida por los atacantes y será la primera sobre la que intenten realizar ataques de diccionario o fuerza bruta para obtener acceso privilegiado al sistema. Deshabilitando esta cuenta y otorgando permisos de administrador a otro usuario puede dificultarles la tarea ya que no sabrán cuál es el nombre de usuario administrador de entre todas las cuentas del sistema, y eso suponiendo que consiguieran listar los usuarios del sistema.
- La cuenta root puede ejecutar cualquier tarea sin rendir cuentas a nadie. Cuando creamos un usuario con permisos de administrador, este usuario debe utilizar el comando sudo para realizar tareas que requieran privilegios y esto deja un registro en el sistema que permite monitorizar qué usuario ha ejecutado qué acción.
- Otro motivo es que al tener cuentas de administrador en lugar de compartir la cuenta de root, podríamos restringir el acceso a un administrador en particular, sin afectar al resto. Un ejemplo claro sería si uno de estos administradores deja la compañía. En lugar de tener que cambiar la contraseña y tener que advertir de ello al resto de administradores, con el consiguiente esfuerzo que supone recordar una contraseña impuesta por otra perona, simplemente podríamos eliminar la cuenta de dicho administrador. Sin mencionar, que la distribución de las credenciales de root puede sufrir riesgo de filtración si no se hace siguiendo unos procedimientos adecuados.
```bash
# Creamos un nuevo usuario administrador.
useradd craxmin -s /bin/bash
# A continuación le asignamos una clave segura (se usa chpasswd en lugar de passwd 
# ya que este comando permite automatizar la asignación de una contraseña cifrada).
echo "craxmin:password_seguro" | chpasswd
# Asignamos el nuevo usuario administrador al grupo sudo (grupo wheel en 
# distribuciones distintas de debian).
usermod -aG sudo craxmin
# Deshabilitamos la cuenta de root.
passwd -l root
```
Otro aspecto que debemos considerar es el de los privilegios que tendrá un usuario no administrador del sistema. En este ejemplo se está gestionando un servicio web, por lo que se entiende que habrá un usuario del servidor que se encargue de levantar el servicio cuando se haya caído y deba acceder a ciertos archivos del sistema que están protegidos.

Una mala política sería otorgarle a esta persona una cuenta de administrador capaz de realizar cualquier acción sobre el sistema, incluso si esta persona y la encargada de la administración del sistema son la misma. Esto garantizará que si se filtra la cuenta que administra el servidor web, las acciones que realice el atacante tendrán un alcance limitado.
```bash
# Creamos un grupo para la gestión de los servicios web
groupadd webadmin

# Creamos un usuario para la gestión del servicio web y lo asignamos al grupo webadmin
useradd webuser1 -s /bin/bash -g webadmin
echo "webuser1:password_seguro" | chpasswd

# Creamos una regla ACL para permitir a los usuarios del grupo webadmin modificar
# los archivos de /var/www/html, que es donde se publican los archivos de la web.
setfacl -Rm g:webadmin:rwx /var/www/html

# Añadimos permisos para iniciar, parar y reiniciar el servidor web a los usuarios del grupo webadmin
echo 'Cmnd_Alias WEBADMIN_SERVICES = /usr/sbin/service nginx start, /usr/sbin/service nginx restart,\
 /usr/sbin/service nginx stop' > /etc/sudoers.d/webadmin-policies
echo '%webadmin ALL=(ALL) WEBADMIN_SERVICES' >> /etc/sudoers.d/webadmin-policies
```



