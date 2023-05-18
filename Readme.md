# Bastionado de servidor Web/SSH
Esta sección del proyecto se centra en la securización de un servidor web al que se puede acceder de forma remota. El bastionado de este nodo tan crítico de la red se realizará llevando a cabo una serie de pasos que se describen a continuación y que se desarrollan más adelante.

1. **Gestión de cuentas:** se crearán cuentas específicas para la administración del servidor web con privilegios limitados mediante políticas de sudo y ACLs. Se creará un usuario administrador y se deshabilitará la cuenta root, para evitar ataques de fuerza bruta sobre este conocido y sensible usuario.

2. **Políticas seguridad y caducidad de cuentas:** se establecerán políticas para obligar a los usuarios a crear contraseñas seguras. Además, se establecerán políticas de caducidad para que los usuarios deban cambiar las contraseñas con cierta frecuencia y evitar la proliferación de cuentas zombie que nadie usa, pero que permanecen activas en el sistema. Adicionalmente, se establecerá un mecanismo de bloqueo automático en cuentas que reciban un número exageradamente elevado de intentos de inicio de sesión inválidos, para evitar ataques de diccionario o de fuerza bruta.

3. **Actualizaciones automáticas:** se configurará un servicio automatizado para la aplicación de parches de seguridad de forma automática para mantener el servidor lo más actualizado posible en todo momento.

4. **Copias de seguridad:** se configurará un mecanismo para la realización de copias de seguridad periódicas de los datos más importantes del servidor.

5. **Análisis activo:** se instalarán y configurarán herramientas de análisis y tratamiento de malware y rootkits.

6. **Cifrado de discos:** se realizará un cifrado del disco para proteger el filtrado de datos en caso de que un atacante consiga acceso físico al servidor.

7. **Monitorización:** se llevará a cabo una minuciosa monitorización del estdo del sistema y de los logs emitidos por las distintas herramientas de detección de intrusiones y detección de malware y rootkits.

8. **Hardening SSH:** se alpicará una configuración segura de SSH mediante el cual se requerirá autenticación con clave pública/privada. Se cambiará el puerto por defecto para dificultar el escaneo por parte de servicios de escaneo masivos. Se configurarán politicas para evitar ataques de fuerza bruta en la autenticación por SSH. Se limitarán el número de conexiones simultáneas sobre el servidor para evitar la sobrecarga y posible caída del mismo. Se configurarán métodos de cifrado seguros y se deshabilitarán los considerados menos seguros.

9. **Banners se seguridad:** se configurarán banners informativos al iniciar sesión para recordar a los usuarios de buenas prácticas para prevenir riesgos de seguridad innecesarios.
---
## 1. Gestión de cuentas
En esta sección se va a configurar un nueva cuenta de administrador, con privilegios de sudo para realizar cualquier acción en el sistema. Al mismo tiempo se deshabilitará la cuenta `root`. La motivación de esto son múltiples:
- La cuenta `root` es muy conocida por los atacantes y será la primera sobre la que intenten realizar ataques de diccionario o fuerza bruta para obtener acceso privilegiado al sistema. Deshabilitando esta cuenta y otorgando permisos de administrador a otro usuario puede dificultarles la tarea ya que no sabrán cuál es el nombre de usuario administrador de entre todas las cuentas del sistema, y eso suponiendo que consiguieran listar los usuarios del sistema.
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
---
## 2. Políticas de seguridad y caducidad de cuentas
En esta sección se configurarán políticas de contraseñas seguras mediante el módulo `PAM` (*Pluggable Authenticaiton Module*) llamado `pwquality`. Por otro lado, la configuración de la caducidad de las cuentas se configurará en el fichero `/etc/login.defs` del sistema operativo. Por último, el bloqueo automático de cuentas se realizarán con otro módulo `PAM` llamado `faillock`.

### 2.1 Configuración del módulo pwquality
Este módulo dispone de un fichero de configuración en la ruta `/etc/security/pwquality.conf` donde podremos establecer los criterios que consideremos adecuados para la creación de contraseñas por parte de los usuarios. Cabe mencionar que un usuario administrado podrá saltarse estas restricciones, aunque se le notificará con una advertencia.

En este fichero realizaremos las siguientes configuraciones:
```bash
# Establecemos la longitud mínima de contraseña en 12 caracteres
minlen = 12

# Obligamos a que la contraseña contenga, al menos, 2 clases de caracteres distintos
# Las clases son (minúsculas, mayúsculas, números y caracteres especiales).
minclass = 2

# Impedimos que el usuario repita el mismo carácter más de dos veces de forma
# consecutiva.
maxrepeat = 2

# Comprobación para que la contraseña no contenga información personal relacionada 
# como nombres, teléfonos, cumpleaños, etc. (Esto solo si cuando se creó la cuenta
# se agregó este tipo de informaciónl).
gecoscheck = 1

# Comprobación básica sobre el diccionario de cracklib para confirmar que no se trate
# de una contraseña de uso muy común y registrada-
dictcheck = 1

# Comprobación de que la contraseña no contenga información del nombre de usuario.
# por ejemplo, username:pepe y contraseña pepe1992
usercheck = 1
```
Estas son unas configuraciones básicas, pero suficientes. Una medida adicional podría ser usar un diccionario más completo, como RockYou, muy popular y ampliamente usado con herramientas como John o Hydra. No obstante, este checkeo podría ralentizar en gran medida el proceso de actualización de las contraseñas y generar una mayor carga en el sistema.

### 2.2 Configuración de la caducidad de las cuentas
Como se ha comentado anteriormente, las políticas de caducidad de las cuentas se pueden establecer de manera general en el archivo `/etc/login.defs`. Veamos qué configuración se ha realizado.
```bash
# Establecemos cada cuanto debe cambiar un usuario la contraseña. Vamos a establecer
# que como máximo deba cambiarla cada 3 meses.
PASS_MAX_DAYS   90

# Vamos a permitir que el usuario pueda cambiar la contraseña tantas veces como 
# quiera, sin restricciones.
PASS_MIN_DAYS   0

# Por último, vamos a establecer un recordatorio al usuario 7 días antes de que
# caduque la contraseña, para que la cambie. Este recordatorio se repetirá todos
# los días haste que se haya cambiado.
PASS_WARN_AGE   7
```
Como acciones adicionales, vamos a cambiar algunos parámetros más de este fichero. Por defecto, las nuevas distribuciones de Ubuntu otorgan unos permisos 750 a los directorios personales. Otras distribuciones, especialmente algunas antiguas,  otorgan privilegios todavía más abiertos. Vamos a configurar este parámetro en 700 para cuando creemos un nuevo usuario (si fuese necesario) solo el propietario del mismo tenga permiso a los datos de su directoriuo perosnal.
```bash
HOME_MODE       0700
```
También vamos a establecer un algoritmo de cifrado seguro para las contraseñas (SHA512) y aumentar el número de rounds, lo que ralentizará en gran medida los ataques de fuerza bruta, otorgando mayor seguridad, a costa de un ligero incremento de la carga de la CPU.
```bash
ENCRYPT_METHOD SHA512
SHA_CRYPT_MIN_ROUNDS 20000
```
Para que lo anterior sea consistente con los módulos PAM, también debemos agregar esta configuración al archivo `/etc/pam.d/common-password`.
```bash
password [success=1 default=ignore] pam_unix.so sha512 rounds=200000
```

### 2.3 Bloqueo automático de cuentas
Finalmente, como medida adicional de seguridad, vamos a establecer una política que bloquee una cuenta temporalmente de forma automática cuando detecte un número elevado de intentos de inicio de sesión incorrectos. Se establecerá un total de 15 intentos, lo cual es un número suficientemente elevado para que un usuario no sufra un bloqueo involuntario por escribir demasiadas veces mal la contraseña y, por otra parte, sigue siendo muy seguro para evitar ataques de fuerza bruta, que requerirán cientos de miles de intentos.

Para establecer estas políticas, haremos uso del módulo `pam_failock`, el cual dispone de un archivo de configuración en `/etc/security/faillock.conf`. Sobre este archivo agregaremos la siguiente configuración.
