# Bastionado de servidor Web/SSH

Esta sección del proyecto se centra en la securización de un servidor web que dispone de una página accesible desde cualquier navegador web y al que se puede acceder de forma remota por SSH, a través del puerto 20222, para su gestión y mantenimiento.

El bastionado de este nodo tan crítico de la red se realizará llevando a cabo una serie de pasos que se describen a continuación y que se desarrollan más adelante.

1. **Gestión de cuentas:** se crearán cuentas específicas para la administración del servidor web con privilegios limitados mediante políticas de sudo y ACLs. Se creará un usuario administrador y se deshabilitará la cuenta root, para evitar ataques de fuerza bruta sobre este conocido y sensible usuario.

2. **Políticas seguridad y caducidad de cuentas:** se establecerán políticas para obligar a los usuarios a crear contraseñas seguras. Además, se establecerán políticas de caducidad para que los usuarios deban cambiar las contraseñas con cierta frecuencia y evitar la proliferación de cuentas zombie que nadie usa, pero que permanecen activas en el sistema. Adicionalmente, se establecerá un mecanismo de bloqueo automático en cuentas que reciban un número exageradamente elevado de intentos de inicio de sesión inválidos, para evitar ataques de diccionario o de fuerza bruta.

3. **Actualizaciones automáticas:** se configurará un servicio automatizado para la aplicación de parches de seguridad de forma automática para mantener el servidor lo más actualizado posible en todo momento.

4. **Análisis activo:** se instalarán y configurarán herramientas de análisis y tratamiento de malware y rootkits.

5. **Monitorización:** se llevará a cabo una minuciosa monitorización del estado del sistema y de los logs emitidos por las distintas herramientas de detección de intrusiones y detección de malware y rootkits.

6. **Hardening SSH:** se aplicará una configuración segura de SSH mediante el cual se requerirá autenticación con clave pública/privada. Se cambiará el puerto por defecto para dificultar el escaneo por parte de servicios de escaneo masivos. Se configurarán políticas para evitar ataques de fuerza bruta en la autenticación por SSH. Se limitarán el número de conexiones simultáneas sobre el servidor para evitar la sobrecarga y posible caída del mismo. Se configurarán métodos de cifrado seguros y se deshabilitarán los considerados menos seguros.

7. **TCP Wrappers:** se configurarán listas de acceso para bloquear las conexiones remotas al servidor a equipos externos a la intranet para obligar a los usuarios a conectarse físicamente o a través de una VPN, aportando un nivel extra de seguridad.

8. **Banners d e seguridad:** se configurarán banners informativos al iniciar sesión para recordar a los usuarios de buenas prácticas para prevenir riesgos de seguridad innecesarios.

---

## 1. Gestión de cuentas

En esta sección se va a configurar un nueva cuenta de administrador, con privilegios de sudo para realizar cualquier acción en el sistema. Al mismo tiempo se deshabilitará la cuenta `root`. La motivación de esto son múltiples:

-   La cuenta `root` es muy conocida por los atacantes y será la primera sobre la que intenten realizar ataques de diccionario o fuerza bruta para obtener acceso privilegiado al sistema. Deshabilitando esta cuenta y otorgando permisos de administrador a otro usuario puede dificultarles la tarea ya que no sabrán cuál es el nombre de usuario administrador de entre todas las cuentas del sistema, y eso suponiendo que consiguieran listar los usuarios del sistema.
-   La cuenta root puede ejecutar cualquier tarea sin rendir cuentas a nadie. Cuando creamos un usuario con permisos de administrador, este usuario debe utilizar el comando sudo para realizar tareas que requieran privilegios y esto deja un registro en el sistema que permite monitorizar qué usuario ha ejecutado qué acción.
-   Otro motivo es que al tener cuentas de administrador en lugar de compartir la cuenta de root, podríamos restringir el acceso a un administrador en particular, sin afectar al resto. Un ejemplo claro sería si uno de estos administradores deja la compañía. En lugar de tener que cambiar la contraseña y tener que advertir de ello al resto de administradores, con el consiguiente esfuerzo que supone recordar una contraseña impuesta por otra persona, simplemente podríamos eliminar la cuenta de dicho administrador. Sin mencionar, que la distribución de las credenciales de root puede sufrir riesgo de filtración si no se hace siguiendo unos procedimientos adecuados.

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

## 2. Políticas de seguridad y caducidad de cuentas

En esta sección se configurarán políticas de contraseñas seguras mediante el módulo `PAM` (_Pluggable Authenticaiton Module_) llamado `pwquality`. Por otro lado, la configuración de la caducidad de las cuentas se configurará en el fichero `/etc/login.defs` del sistema operativo. Por último, el bloqueo automático de cuentas se realizarán con otro módulo `PAM` llamado `faillock`.

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

Como acciones adicionales, vamos a cambiar algunos parámetros más de este fichero. Por defecto, las nuevas distribuciones de Ubuntu otorgan unos permisos 750 a los directorios personales. Otras distribuciones, especialmente algunas antiguas, otorgan privilegios todavía más abiertos. Vamos a configurar este parámetro en 700 para cuando creemos un nuevo usuario (si fuese necesario) solo el propietario del mismo tenga permiso a los datos de su directoriuo perosnal.

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

Finalmente, como medida adicional de seguridad, vamos a establecer una política que bloquee una cuenta temporalmente de forma automática cuando detecte un número elevado de intentos de inicio de sesión incorrectos. Se establecerá un total de 15 intentos, lo cual es un número suficientemente elevado para que un usuario no sufra un bloqueo involuntario por escribir varias veces mal la contraseña y, por otra parte, sigue siendo muy seguro para evitar ataques de fuerza bruta y de diccionario, que requerirán cientos de miles de intentos.

Para establecer estas políticas, haremos uso del módulo `pam_failock`. Este módulo debe ser configurado en tres sitios.

**Configuración del faillock:** El primero de ellos es el archivo de configuración del propio módulo, donde indicaremos, entre otras cosas, el número máximo de intentos de inicio de sesión consecutivos y el tiempo de bloqueo. Este archivo se ubica en la ruta `/etc/security/faillock.conf`.

```bash
# Activamos la auditoría de usuarios que intentan autenticarse.
audit

# Desactivamos mensajes informativos para no facilitar al atacante conocer detalles
# como que un usuario existe o no en el sistema.
silent

# Establecemos el bloqueo de la cuenta tras 15 intentos de inicio de sesión incorrectos
deny = 15

# Para que la cuenta se bloquee, los 15 intentos de inicio de sesión se deben dar en
# el intervalo de tiempo indicado a continuación. Esto es para evitar que se acumulen
# inicios de sesión fallidos de un día para otro. Este campo lo establecemos a 900
# segundos (15 minutos), lo que deja una media de 1 intento de inicio de sesión por
# minuto (más el tiempo de bloqueo).
fail_interval = 900

# Tiempo que permanecerá bloqueada la cuenta 600 segundos (10 minutos)
unlock_time = 600
```

**Fase de autenticación:** el proceso de autenticación se gestiona desde el archivo `/etc/pam.d/common-auth`. En este archivo encontraremos una línea que carga el módulo `pam_unix.so`, que es el encargado de la autenticación como tal. Deberemos configurar el módulo faillock tanto antes (preautenticación) como después (postautenticación) del módulo `pam_unix.so`. La preautenticación comprobará si la cuenta a la que se intenta iniciar sesión se encuentra ya bloqueada, en ese caso no iniciará ningún proceso de autenticación posterior, denegando automáticamente el acceso. Tras pasar la fase de preautenticación, si no se ha bloqueado, entonces comienza la autenticación en el módulo `pam_unix.so`. Si la autenticación es satisfactoria, se inicia sesión normalmente, en otro caso, actúa el módulo de postautenticación, incrementando el contador de inicios de sesión incorrectos y bloqueando la cuenta en caso necesario. Debemos modificar la línea `pam_unix.so` como se ve en el siguiente ejemplo y agregar las líneas del módulo faillock antes y después, tal y como se ve en el ejemplo.

```bash
auth    required                        pam_faillock.so preauth
auth    sufficient                      pam_unix.so
auth    [default=die]                   pam_faillock.so authfail
```

**Verificación de cuentas:** como último paso, debemos indicar este módulo en la configuración de las cuentas. Aquí, este módulo se encargará del manejo de bloqueo de cuentas basado en los intentos de inicio de sesión fallidos. El archivo donde hay que agregar esta configuración es `/etc/pam.d/common-account`, antes de la línea de `pam_unix.so`.

```bash
account  required       pam_faillock.so
```

## 3. Actualizaciones automáticas

Uno de los aspectos más importantes relativos a la seguridad es el de mantener nuestro sistema constantemente actualizado, especialmente cuando se trata de parches de seguridad. Por este motivo, se va a automatizar la descarga e instalación de las actualizaciones de seguridad de forma desatendida. Para esta tarea se hará uso del paquete `unattended-upgrades`.

Una vez instalado el paquete, se nos habilitarán varios archivos en `/etc/apt/apt.conf.d`. Concretamente, en el archivo `50unnatended-upgrades` vamos a encontrar la configuración de los paquetes que deseamos trackear de forma automática. Aquí no debemos hacer nada, ya que por defecto solo se seleccionan los relativos a las actualizaciones de seguridad.

```bash
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}";
        "${distro_id}:${distro_codename}-security";
        // Extended Security Maintenance; doesn't necessarily exist for
        // every release and this system may not have it installed, but if
        // available, the policy for updates is such that unattended-upgrades
        // should also install from here by default.
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
//      "${distro_id}:${distro_codename}-updates";
//      "${distro_id}:${distro_codename}-proposed";
//      "${distro_id}:${distro_codename}-backports";
};
```

Además del archivo anterior, también debemos agregar la siguiente configuración al archivo `/etc/pam/pam.conf.d/20auto-upgrades`, el cual contiene la información sobre si se van a actualizar los repositorios, descargar los paquetes, instalarlos y el período de purga de paquetes o dependencias huérfanas.

```bash
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
```

La primera línea indica que deben actualizarse las listas de repositorios, la segunda línea que se deben descargar las actualizaciones, la cuarta que deben instalarse sin atención del usuario y la tercera que cada 7 días debe realizares una limpieza automática de paquetes (`autoremove`).

Aunque las actualizaciones se realizan de forma automática, algunas de ellas requieren de reiniciar el servidor para poder aplicarse. No obstante, como estamos administrando un servidor web para el cual no se ha configurado ningún tipo de redundancia, delegar la tarea de reiniciar el servidor de forma automática no se contempla. De modo que el administrador será el encargado de reiniciarlo cuando considere oportuno.

## 4. Análisis activo

En esta sección se configurarán herramientas de escaneo activas para la detección de malware y virus. Como antivirus se ha elegido ClamAV por ser una alternativa gratuita para linux y a la vez bastante popular. Como herramienta para la detección de rootkits se empleará Rootkit Hunter.

### 4.1 ClamAV

Para la configuración del antivirus ClamAV, se aplicará una configuración automática de los demonios freshclam, encargado de mantener la base de datos de virus actualizada y clamav, encargado del análisis automático del sistema. Para configurar estos demonios se ha empleado dpkg-reconfigure.

```bash
sudo dkpg-reconfigure clamav-freshclam
sudo dkpg-reconfigure clamav-daemon
```

Estos comandos modifican automáticamente la configuración de los archivos `/etc/clamav/fresclam.conf` y `/etc/clamav/clamd.conf`. Algunos de los parámetros configurados (se muestra el contenido de los archivos de configuración) han sido los siguientes.

#### **Parámetros principales configurados en freshclam**

```bash
# Ubicación de los archivos de log
UpdateLogFile /var/log/clamav/freshclam.log

# Activamos la rotación de logs para evitar ficheros demasiado grandes
LogRotate true

# Incluimos el registro de la hora en los eventos de log
LogTime true

# Establecemos el directorio donde se guardarán las bases de datos de firmas de virus
DatabaseDirectory /var/lib/clamav

# Esta opción permite acelerar el análisis de archivos
Bytecode true

# Las comprobaciones de actualizaciones se realizan 24 veces al día
Checks 24

# Establecemos un mirror de españa para tener mejor conectividad
DatabaseMirror db.es.clamav.net
```

#### **Parámetros principales configurados en clamd**

```bash
# Establecemos un socket local con permisos abiertos
LocalSocket /var/run/clamav/clamd.ctl
LocalSocketGroup clamav
LocalSocketMode 666

# usuario que se usará para el análisis
User clamav

# Activamos la rotación de logs
LogRotate true

# Definimos dónde se encuentra la base de datos de firmas de virus
DatabaseDirectory /var/lib/clamav

# Establecemos un checkeo de integridad cada hora para que ClamAV compruebe
# sus componentes y bases de datos de firmas.
SelfCheck 3600

# Establecemos algunos límites de escaneo
MaxScanTime 120000
MaxScanSize 100M
MaxFileSize 25M
MaxRecursion 16
MaxFiles 10000

# Especificamos dónde se alamacenarán los logs y registraremos la hora de suceso
LogFile /var/log/clamav/clamav.log
LogTime true

# Activamos el bytecode para mejorar el rendimiento
Bytecode true
BytecodeSecurity TrustSigned
BytecodeTimeout 60000
```

Continúa en desarrollo...

## 5. Monitorización

Próximamente...

## 6. Hardening SSH

Para proveer acceso remoto al servidor, se va a hacer uso del servidor `openssh`. Por defecto, este servidor ofrece unas políticas no demasiado seguras, por lo que se va a realizar una configuración del servicio para garantizar una mayor seguridad.

Entre otras cosas, las medidas que se van a aplicar van a ser la de cambiar el puerto por defecto, activar la autenticación únicamente con clave pública, prohibir el acceso root directamente, limitar el número de sesiones simultáneas y deeshabilitar todas las características que no necesitamos.

Para realizar la configuración del servicio, se modificará el archivo `/etc/ssh/sshd_config`. Sobre este archivo realizaremos los siguientes cambios.

```bash
# Cambiaremos el puerto por defecto (22) por otro puerto poco conocido. Esto
# dificultará a los bots de la red, así como a otros atacantes, detectar la
# existencia de nuestro servicio SSH y que intenten explotarlo.
Port 20222

# Inhabilitamos el acceso con root (aunque esta cuenta ya esté deshabilitada).
# Para tareas de administración conectarse con usuario sin privilegios y luego sudo.
PermitRootLogin no

# Limitamos los intentos de inicio de sesión a 3 antes de que el servidor cierre
# la conexión. Tras ello, el usuario deberá establecer nuevamente la conexión.
# Recordar que, tras 15 intentos, la cuenta se bloqueará (faillock).
MaxAuthTries 3

# Limitamos el número máximo de conexiones simultáneas en el servidor a 5 para
# evitar una posible sobrecarga del mismo.
MaxSessions 5

# Desactivamos las redirecciones de entorno gráfico
X11Forwarding no

# Desactivamos el acceso por usuario/clave, solo permitiremos el acceso por clave
# pública/privada, que es más seguro (previa copia de las claves del cliente al
# servidor).
PasswordAuthentication no
PubkeyAuthentication yes

# Desactivamos túneles SSH que no necesitamos
AllowAgentForwarding no
PermitTunnel no
AllowTcpForwarding no
GatewayPorts no

# Evitamos dar información sobre el último login.
PrintLastLog no

# Evitamos que el servidor envíe peticiones KeepAlive para mantener las sesiones
# activas. Esto puede ayudar ligeramente a prevenir algunos intentos de spoofing.
TCPKeepAlive no

# Activamos la visualización del banners de seguridad. Este banner se creará más
# adelante, pero podemos ir definiendo ya la ruta donde lo ubicaremos.
Banner /etc/ssh/sshd-banner
```

Esta parte es compleja de automatizar en Docker debido a la necesidad de tener que generar las claves públicas en los clientes que tendrán acceso al servicio SSH. Por este motivo, para el despliegue se dejará habilitada la opción de autenticación con usuario y contraseña y, una vez generadas y copiadas las claves públicas al servidor, se deberá desactivar esta opción, tal y como se muestra en el ejemplo anterior.

## 7. TCP Wrappers

Por último, y a pesar de que en la topología donde se implanta este servidor ya existe un firewall dedicado que bloquea todas las conexiones indeseadas, se van a implementar listas de acceso de al servidor SSH para permitir la conexión únicamente a equipos que se conecten desde dentro de la red interna. Esto conlleva que un usuario deba estar conectado físicamente en la red de la compañía o a través de una VPN, agregando una capa más de seguridad.

Para agregar estas listas debemos configurar los archivos `/etc/hosts.allow` y `/etc/hosts.deny`. El primero de ellos establece una lista blanca que solo permite la conexión a los equipos definidos en ella. El segundo archivo hace justo lo contrario, bloquea el acceso a todos los equipos que estén incluidos en dicha lista.

El funcionamiento de los TCP Wrappers es sencillo, primero se mira el archivo `hosts.allow`, si se encuentra el host, se permite el acceso. Si no se encuentra el host, entonces se comprueba la lista negra `hosts.deny`. Si se encuentra en la lista negra, se le deniega el acceso, si no, se le concede acceso.

Dicho esto, denegaremos a todos los hosts en la lista negra y en la lista blanca daremos acceso únicamente a los equipos de la intranet (172.16-32.0.0).

**/etc/hosts.deny**

```bash
SSHD: ALL
```

**/etc/hosts.allow**

```bash
SSHD: 172.16.0.0/12
```

## 8. Banners de seguridad

Se conoce que, dentro de la cadena de seguridad informática, el usuario suele ser el eslabón más débil, debido generalmente a su desconocimiento y falta de preparación. Para tratar de mitigar en cierta medida este hecho, resulta de interés mostrar al usuario algunos tips de buenas prácticas a la hora de trabajar con un sistema informático.

Para mostrar estos tips de seguridad, vamos a hacer uso del archivo `/etc/ssh/sshd-banner`, el cual no existirá por defecto, pero lo podemos crear y su contenido se mostrará cada vez que el usuario inicie sesión de forma remota. Como este servidor será accedido esencialmente para la gestión del servicio web de forma remota, los tips irán dirigidos al encargado de gestionar el servicio web. Los tips que se mostrarán serán:

1. Si abandonas momentáneamente tu puesto de trabajo, no olvides bloquear la sesión.
2. No compartas con nadie la contraseña de acceso y cámbiala con frecuencia, o inmediatamente si tienes la sospecha de que ha sido filtrada.
3. No descargues nada ni accedas a la red para realizar consultas desde este servidor.
4. Si detectas cualquier anomalía en el sistema, contacta inmediatamente con el administrador.
5. Si sospechas que tu equipo ha podido ser infectado con un virus, no trates de conectarte a la red ni acceder al servidor y contacta inmediatamente con el administrador.
