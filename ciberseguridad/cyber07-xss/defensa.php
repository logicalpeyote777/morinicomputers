<?php
/*  defensa.php  --  Como se BLINDA una web contra XSS y CSRF (el patron correcto).
 *  Morini Computers -- Ciberseguridad. Educativo y de defensa. Laboratorio aislado.
 *  Es el mismo enfoque del nivel "impossible" de DVWA. Tres capas:
 *    1) escapar TODA salida -> mata el XSS (reflejado y almacenado)
 *    2) token anti-CSRF + comprobar la contrasena actual -> mata el CSRF
 *    3) cookie de sesion HttpOnly + SameSite -> aunque haya XSS, no roban la sesion
 */

/* ---------- 1) DEFENSA XSS: escapar la salida (output encoding) ---------- */
// NUNCA imprimas datos del usuario tal cual. htmlspecialchars convierte < > " ' &
// en entidades, asi el navegador los pinta como TEXTO y nunca como codigo.
$name = htmlspecialchars($_GET['name'] ?? '', ENT_QUOTES, 'UTF-8');
echo "<pre>Hello {$name}</pre>";          // <script> llega como &lt;script&gt; -> inerte

/* ---------- 2) DEFENSA CSRF: token de un solo uso + clave actual ---------- */
// El formulario incluye un token secreto e impredecible ligado a la sesion; una
// pagina trampa de otro sitio NO puede adivinarlo, asi que su peticion se rechaza.
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkToken($_POST['user_token'] ?? '', $_SESSION['session_token'] ?? '', 'index.php');
    // y ademas exige la contrasena ACTUAL: un CSRF a ciegas no la conoce.
    if (verificar_password_actual($_POST['password_current'] ?? '')) {
        $stmt = $pdo->prepare('UPDATE users SET password = :p WHERE user = :u');
        $stmt->execute([':p' => password_hash($_POST['password_new'], PASSWORD_DEFAULT),
                        ':u' => $_SESSION['user']]);
    }
    generateSessionToken();   // token nuevo para la siguiente peticion
}

/* ---------- 3) DEFENSA del robo de sesion: la cookie, blindada ---------- */
// HttpOnly  -> JavaScript NO puede leer document.cookie (el XSS no roba la sesion).
// Secure    -> la cookie solo viaja por HTTPS.
// SameSite  -> el navegador no la manda en peticiones de otros sitios (frena el CSRF).
session_set_cookie_params([
    'httponly' => true,
    'secure'   => true,
    'samesite' => 'Strict',
]);
session_start();

/*  Resumen:  escapa la salida + token anti-CSRF + cookie HttpOnly/SameSite.
 *  Con estas tres, el ataque del video (robar la sesion y forjar el cambio de clave)
 *  deja de funcionar.  */
