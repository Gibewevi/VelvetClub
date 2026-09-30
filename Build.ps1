$ErrorActionPreference = 'Stop'
# Jeu de gestion en pixel art isométrique (projet pixel/).
$projectRoot = $PSScriptRoot
$version = 'Construction-V46-Fumee-BD'
$godotBinary = Join-Path $projectRoot '.tools\godot\Godot_v4.5.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotBinary)) {
    throw 'Godot 4.5.1 est absent de .tools/godot. Voir README.md.'
}
$gameDir = Join-Path $projectRoot 'pixel'
$testData = Join-Path $projectRoot '.tools\userdata'
$artifacts = Join-Path $projectRoot 'tests\artifacts'
New-Item -ItemType Directory -Path $testData,$artifacts,(Join-Path $projectRoot 'build') -Force | Out-Null

# 1. Sprites : tout le pixel art est redessiné à sa résolution finale (Python + numpy + Pillow).
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    Push-Location (Join-Path $projectRoot 'tools\pixelart')
    try {
        & python build_art.py
        if ($LASTEXITCODE -ne 0) { throw 'Génération du pixel art échouée.' }
    } finally { Pop-Location }
} else {
    Write-Host 'Python absent : les sprites déjà générés dans pixel/art sont utilisés.'
}

$previousAppData = $env:APPDATA
try {
    $env:APPDATA = $testData
    & $godotBinary --headless --path $gameDir --editor --import --quit --log-file (Join-Path $artifacts 'pixel-import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Import du projet échoué.' }
    & $godotBinary --headless --path $gameDir --script res://tests/model_test.gd --log-file (Join-Path $artifacts 'pixel-model.log')
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-model.log') -Pattern 'MODEL_TESTS_PASSED' -Quiet)) { throw 'Tests du modèle échoués.' }
    & $godotBinary --headless --path $gameDir --script res://tests/parking_fit_test.gd --log-file (Join-Path $artifacts 'pixel-parking-fit.log')
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-parking-fit.log') -Pattern 'PARKING_FIT_TESTS_PASSED' -Quiet)) { throw 'Calcul des places de parking échoué.' }
    & $godotBinary --headless --path $gameDir --script res://tests/art_test.gd --log-file (Join-Path $artifacts 'pixel-art.log')
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-art.log') -Pattern 'ART_TESTS_PASSED' -Quiet)) { throw 'Contrôle du pixel art échoué.' }
    & $godotBinary --headless --path $gameDir --script res://tests/delivery_dust_test.gd --log-file (Join-Path $artifacts 'pixel-delivery-dust.log')
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-delivery-dust.log') -Pattern 'DELIVERY_DUST_TESTS_PASSED' -Quiet)) { throw 'Test de la fumée BD échoué.' }
    & $godotBinary --headless --path $gameDir --script res://tests/quick_service_test.gd --log-file (Join-Path $artifacts 'pixel-quick.log')
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-quick.log') -Pattern 'QUICK_SERVICE_TESTS_PASSED' -Quiet)) { throw 'Test de la prestation rapide échoué.' }
    & $godotBinary --headless --path $gameDir --log-file (Join-Path $artifacts 'pixel-delivery.log') -- --delivery-test
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-delivery.log') -Pattern 'DELIVERY_TEST_PASSED' -Quiet)) { throw 'Tests des commandes et livraisons échoués.' }
    & $godotBinary --headless --path $gameDir --log-file (Join-Path $artifacts 'pixel-smoke.log') -- --smoke-test
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-smoke.log') -Pattern 'SMOKE_TEST_PASSED' -Quiet)) { throw 'Test de scène échoué.' }
    & $godotBinary --headless --path $gameDir --log-file (Join-Path $artifacts 'pixel-sim.log') -- --sim-test
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-sim.log') -Pattern 'SIM_TEST_PASSED' -Quiet)) { throw 'Simulation d''une nuit échouée.' }
    # L'interface se teste dans une vraie fenêtre (clics simulés), quelques secondes.
    & $godotBinary --path $gameDir --log-file (Join-Path $artifacts 'pixel-ui.log') -- --ui-test
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath (Join-Path $artifacts 'pixel-ui.log') -Pattern 'UI_TEST_PASSED' -Quiet)) { throw "Test d'interface échoué." }
    & $godotBinary --headless --path $gameDir --export-release 'Windows Desktop' (Join-Path $projectRoot "build\$version.exe") --log-file (Join-Path $artifacts 'pixel-export.log')
    if ($LASTEXITCODE -ne 0) { throw 'Export Windows échoué. Fermez le jeu et réessayez.' }
    Write-Host "Jeu prêt : build\$version.exe"
} finally {
    $env:APPDATA = $previousAppData
}
