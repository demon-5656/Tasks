<?php
$node = gethostname();
$imageUrl = getenv('IMAGE_URL') ?: '__IMAGE_URL__';
header('X-Backend-Id: ' . $node);
header('Cache-Control: no-store');
?>
<!doctype html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LAMP — балансировка нагрузки</title>
  <style>
    body { max-width: 960px; margin: 40px auto; padding: 0 24px; font: 18px/1.5 system-ui, sans-serif; color: #18243a; }
    code { background: #eef2f7; padding: 4px 8px; border-radius: 5px; }
    img { display: block; width: 100%; height: auto; margin-top: 24px; border-radius: 12px; }
  </style>
</head>
<body>
  <h1>Веб-сервер за балансировщиком</h1>
  <p>Ответ подготовил узел <code id="backend"><?= htmlspecialchars($node, ENT_QUOTES, 'UTF-8') ?></code>.</p>
  <p>Картинка загружается отдельным запросом из Object Storage:</p>
  <a href="<?= htmlspecialchars($imageUrl, ENT_QUOTES, 'UTF-8') ?>">
    <img src="<?= htmlspecialchars($imageUrl, ENT_QUOTES, 'UTF-8') ?>" alt="Object Storage и три веб-сервера">
  </a>
</body>
</html>
