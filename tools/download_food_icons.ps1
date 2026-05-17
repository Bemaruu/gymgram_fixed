$ErrorActionPreference = 'Continue'
$dest = 'c:\Users\benja\gymgram_fixed\assets\icons\food'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$items = @(
  @{name='food_meat';      cp='1F969'},
  @{name='food_chicken';   cp='1F357'},
  @{name='food_fish';      cp='1F41F'},
  @{name='food_egg';       cp='1F95A'},
  @{name='food_dairy';     cp='1F95B'},
  @{name='food_grain';     cp='1F33E'},
  @{name='food_bread';     cp='1F35E'},
  @{name='food_rice';      cp='1F35A'},
  @{name='food_pasta';     cp='1F35D'},
  @{name='food_fruit';     cp='1F34E'},
  @{name='food_veggie';    cp='1F966'},
  @{name='food_legume';    cp='1FAD8'},
  @{name='food_nuts';      cp='1F95C'},
  @{name='food_avocado';   cp='1F951'},
  @{name='food_sweet';     cp='1F370'},
  @{name='food_drink';     cp='1F964'},
  @{name='food_water';     cp='1F4A7'},
  @{name='food_coffee';    cp='2615'},
  @{name='food_supplement';cp='1F48A'},
  @{name='food_snack';     cp='1F36A'},
  @{name='food_fastfood';  cp='1F354'}
)

foreach ($i in $items) {
  $out = Join-Path $dest ($i.name + '.svg')
  $u1  = "https://openmoji.org/data/color/svg/$($i.cp).svg"
  $u2  = "https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/svg/$($i.cp).svg"
  $ok  = $false
  try {
    Invoke-WebRequest -Uri $u1 -OutFile $out -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
    if ((Get-Item $out).Length -gt 0) { $ok = $true }
  } catch {}
  if (-not $ok) {
    try {
      Invoke-WebRequest -Uri $u2 -OutFile $out -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
      if ((Get-Item $out).Length -gt 0) { $ok = $true }
    } catch {}
  }
  if ($ok) {
    $sz = (Get-Item $out).Length
    Write-Host "OK   $($i.name) cp=$($i.cp) ${sz}b"
  } else {
    Write-Host "FAIL $($i.name) cp=$($i.cp)"
  }
}
