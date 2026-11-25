# Slices assets/icon/upgradables.png (3x2 grid of upgrade icons on white)
# into six trimmed, white-keyed transparent PNGs in assets/icon/upgrades/.
#
# Cell order matches GameConfig.ShopUpgrade:
#   speed, luck, jump  (top row)
#   heart, shield, dash (bottom row)
#
# Run from the repository root:  powershell -File tools\slice_upgrades.ps1

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$srcPath = Join-Path $root "assets\icon\upgradables.png"
$outDir = Join-Path $root "assets\icon\upgrades"
$names = @("speed", "luck", "jump", "heart", "shield", "dash")

$src = New-Object System.Drawing.Bitmap($srcPath)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$cols = 3
$rows = 2
$cellW = [int][Math]::Floor($src.Width / $cols)
$cellH = [int][Math]::Floor($src.Height / $rows)

# Read every pixel once.
$rect = New-Object System.Drawing.Rectangle(0, 0, $src.Width, $src.Height)
$data = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($data.Stride * $src.Height)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$src.UnlockBits($data)

function Test-Background([byte]$b, [byte]$g, [byte]$r, [byte]$a) {
	return ($a -lt 10) -or ($r -ge 240 -and $g -ge 240 -and $b -ge 240)
}

for ($r = 0; $r -lt $rows; $r++) {
	for ($c = 0; $c -lt $cols; $c++) {
		$name = $names[$r * $cols + $c]
		$x0 = $c * $cellW
		$y0 = $r * $cellH
		$minX = $cellW; $minY = $cellH; $maxX = -1; $maxY = -1

		# Bounding box of non-background pixels inside this cell.
		for ($y = $y0; $y -lt $y0 + $cellH; $y++) {
			$rowBase = $y * $data.Stride
			for ($x = $x0; $x -lt $x0 + $cellW; $x++) {
				$i = $rowBase + $x * 4
				if (-not (Test-Background $bytes[$i] $bytes[$i + 1] $bytes[$i + 2] $bytes[$i + 3])) {
					if ($x -lt $minX) { $minX = $x }
					if ($y -lt $minY) { $minY = $y }
					if ($x -gt $maxX) { $maxX = $x }
					if ($y -gt $maxY) { $maxY = $y }
				}
			}
		}
		if ($maxX -lt 0) {
			Write-Warning "cell '$name' is empty; skipped"
			continue
		}

		$pad = 2
		$minX = [Math]::Max($x0, $minX - $pad)
		$minY = [Math]::Max($y0, $minY - $pad)
		$maxX = [Math]::Min($x0 + $cellW - 1, $maxX + $pad)
		$maxY = [Math]::Min($y0 + $cellH - 1, $maxY + $pad)
		$w = $maxX - $minX + 1
		$h = $maxY - $minY + 1

		$icon = New-Object System.Drawing.Bitmap($w, $h)
		$outData = $icon.LockBits((New-Object System.Drawing.Rectangle(0, 0, $w, $h)), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
		$outBytes = New-Object byte[] ($outData.Stride * $h)
		for ($y = 0; $y -lt $h; $y++) {
			$srcRow = ($y + $minY) * $data.Stride
			$outRow = $y * $outData.Stride
			for ($x = 0; $x -lt $w; $x++) {
				$si = $srcRow + ($x + $minX) * 4
				$di = $outRow + $x * 4
				if (Test-Background $bytes[$si] $bytes[$si + 1] $bytes[$si + 2] $bytes[$si + 3]) {
					# White (or already transparent) becomes fully transparent.
					$outBytes[$di + 3] = 0
				} else {
					$outBytes[$di] = $bytes[$si]
					$outBytes[$di + 1] = $bytes[$si + 1]
					$outBytes[$di + 2] = $bytes[$si + 2]
					$outBytes[$di + 3] = 255
				}
			}
		}
		[System.Runtime.InteropServices.Marshal]::Copy($outBytes, 0, $outData.Scan0, $outBytes.Length)
		$icon.UnlockBits($outData)
		$outPath = Join-Path $outDir "$name.png"
		$icon.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
		$icon.Dispose()
		Write-Host "wrote $outPath ($w x $h)"
	}
}

$src.Dispose()
Write-Host "done"
