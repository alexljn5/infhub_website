<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to the INFHUB project!</title>
    <link rel="icon" type="image/ico" href="./img/logo/infhub_favicon.ico">
    <link rel="stylesheet" href="css/styles.css">
    <script src="js/clickableboxes.js" defer></script>
</head>

<body>
    <div class="asciiWrapper">
        <pre class="bunnyAsciiLeft">
<?php
$path = __DIR__ . '/img/misc/bnuuyascii.txt';
if (file_exists($path)) {
    echo nl2br(htmlspecialchars(file_get_contents($path)));
} else {
    echo "Bunny NOT found";
}
?>
    </pre>
        <div class="logoContainer">
            <pre class="logoAscii">
<?php
$path = __DIR__ . '/img/logo/infhub/infhub_ascii.txt';

if (file_exists($path)) {
    echo nl2br(htmlspecialchars(file_get_contents($path)));
} else {
    echo "File NOT found: " . $path;
}
?>
    </pre>
        </div>
        <pre class="bunnyAsciiRight">
<?php
$path = __DIR__ . '/img/misc/bnuuyascii.txt';
if (file_exists($path)) {
    echo nl2br(htmlspecialchars(file_get_contents($path)));
} else {
    echo "Bunny NOT found";
}
?>
    </pre>
    </div>
    <div class="boxContainers">
        <div class="serverBox" id="infcraftBox" data-server="infcraft">
            <img src="./img/logo/infcraft/infcraft_logo.png" alt="INFCRAFT" class="serverImage">
            <p>INFCRAFT</p>
        </div>
        <div class="serverBox" id="serverBox2" data-server="server2">
            <img src="./img/misc/pixel_art_burger.png" alt="Server 2" class="serverImage">
            <p>Server 2</p>
        </div>
        <div class="serverBox" id="serverBox3" data-server="server3">
            <img src="./img/misc/pixel_art_burger.png" alt="Server 3" class="serverImage">
            <p>Server 3</p>
        </div>
    </div>

    <?php include('./php/footer.php'); ?>
</body>

</html>