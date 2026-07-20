<?php
require 'vendor/autoload.php';
use Panteao\Panteao;
$engine = new Panteao("./project.jcm");
$engine->connect();
$engine->loop();