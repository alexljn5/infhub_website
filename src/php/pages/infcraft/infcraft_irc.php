<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IRC Chat</title>
    <link rel="icon" type="image/ico" href="/img/logo/favicon.ico">
    <link rel="stylesheet" href="/css/infcraft/infcraft.css">
</head>

<body>
    <?php include('../../templates/infcraft/infcraft_header.php'); ?>

    <?php
    // Use Docker service name for The Lounge (falls back to localhost for local dev)
    $lounge_host = getenv('LOUNGE_HOST') ?: 'localhost';
    $lounge_port = getenv('LOUNGE_PORT') ?: '9000';
    $lounge_url = "http://$lounge_host:$lounge_port";
    ?>
    <div id="irc-container" style="width:100%; height:800px;">
        <iframe src="<?php echo $lounge_url; ?>" style="width:100%; height:100%; border:none;" title="INFHUB IRC Chat">
        </iframe>
    </div>

    <?php include('../../templates/footer.php'); ?>

</body>

</html>