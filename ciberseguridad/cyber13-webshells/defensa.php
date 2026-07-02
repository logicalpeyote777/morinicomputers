<?php
// defensa.php -- COMO se cierra cada una de las tres puertas de este video.
// No es codigo para ejecutar: es el patron correcto frente al vulnerable.
// Laboratorio aislado y propio; solo fines educativos. Morini Computers -- Ciberseguridad.

// -------------------------------------------------------------------------
// 1) COMMAND INJECTION  (el formulario de "hacer ping")
// -------------------------------------------------------------------------
// MAL: pegar la entrada del usuario dentro de un comando del sistema.
//      shell_exec('ping -c 4 ' . $_POST['ip']);      // <-- ; | && cuelan comandos
// BIEN: nunca construyas comandos con texto del usuario. Valida el formato y
//       escapa SIEMPRE cada argumento con escapeshellarg().
$ip = $_POST['ip'] ?? '';
if (!filter_var($ip, FILTER_VALIDATE_IP)) {
    die('Direccion IP no valida.');                    // solo una IP real pasa
}
$salida = shell_exec('ping -c 4 ' . escapeshellarg($ip));

// -------------------------------------------------------------------------
// 2) LFI / RFI  (el parametro ?page= que incluye ficheros)
// -------------------------------------------------------------------------
// MAL: include($_GET['page']);   // permite ../../etc/passwd y php://filter
// BIEN: nunca incluyas una ruta que venga del usuario. Usa una LISTA BLANCA.
$permitidas = ['home.php', 'ayuda.php', 'contacto.php'];
$page = basename($_GET['page'] ?? 'home.php');         // corta cualquier ../
if (!in_array($page, $permitidas, true)) {
    $page = 'home.php';                                // fuera de la lista -> por defecto
}
include __DIR__ . '/paginas/' . $page;
// Y en php.ini, para matar el RFI de raiz (es el valor por defecto):
//     allow_url_include = Off

// -------------------------------------------------------------------------
// 3) SUBIDA DE ARCHIVOS  (por donde entra la webshell)
// -------------------------------------------------------------------------
// MAL: guardar el archivo con su nombre original y confiar en el Content-Type.
// BIEN: lista blanca de extension REAL + nombre aleatorio + carpeta sin ejecucion.
$permitidas_ext = ['jpg', 'jpeg', 'png', 'gif'];
$ext = strtolower(pathinfo($_FILES['uploaded']['name'], PATHINFO_EXTENSION));
$tipo = mime_content_type($_FILES['uploaded']['tmp_name']);   // tipo REAL, no el que dice el navegador
if (!in_array($ext, $permitidas_ext, true) || strpos($tipo, 'image/') !== 0) {
    die('Solo se permiten imagenes.');
}
$destino = '/var/www/uploads/' . bin2hex(random_bytes(16)) . '.' . $ext;  // nombre impredecible
move_uploaded_file($_FILES['uploaded']['tmp_name'], $destino);
// Ademas, en la config del servidor, la carpeta de subidas NO debe ejecutar PHP:
//   <Directory /var/www/uploads>  php_admin_flag engine off  </Directory>
// Asi, aunque colasen un .php, el servidor lo sirve como texto y nunca se ejecuta.
?>
