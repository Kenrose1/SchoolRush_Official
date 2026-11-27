# Cuts the slide sheet (tools/sources/elias_slide_sheet.png, 1600x200, 8 cells)
# into Elias's slide frames in assets/characters/elias/.
#
# The sheet runs: two run strides, a crouch, a sit-back, two slide poses and a
# rise. The slide animation uses the five crouch-to-rise cells (2..6), so one
# SLIDE_DURATION pass reads as duck -> down -> up instead of a held pose.
#
# Frames are drawn on a 180x189 canvas with the art's ground line on y=186,
# matching the idle/slide canvases the sprite is anchored to (the frame bottom
# is the lane baseline). The figure is scaled to the 185 px standing height of
# the rest of the Elias art, and each cell is centred on its painted bounds.
#
# Run from the repository root:  powershell -File tools\build_elias_slide.ps1

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sheetPath = Join-Path $root "tools\sources\elias_slide_sheet.png"
$outDir = Join-Path $root "assets\characters\elias"

# Cells 2..6 of the sheet, in animation order.
$cells = @(2, 3, 4, 5, 6)
$cellSize = 200
# Ground line (y) shared by every cell in the sheet.
$sheetGround = 180
# Painted height of the sheet's standing pose (cell 7) and the height these
# frames are drawn at.
#
# Deliberately shorter than the 185 px standing art: the only thing Elias slides
# under is the road barrier, whose painted beam underside hangs (511 - 141) px
# of its 511 px height above the road - 99.6 px at its 0.27 scale. The Player
# node renders the sprite at 0.6 x 1.3 = 0.78, so art taller than ~128 canvas px
# pokes through the beam while the 51 px slide hitbox still clears it. At 140
# the crouch entry is 113 canvas px (88 px on screen), a real duck under the
# beam, and the lying poses land near the old slide art's height.
$sheetFigure = 166
$targetFigure = 140
# Output canvas: as tall as the other states, wide enough for the extended
# lying pose, with the ground line where the idle frames put it.
$canvasW = 180
$canvasH = 189
$groundY = 186

$scale = $targetFigure / $sheetFigure

$src = New-Object System.Drawing.Bitmap($sheetPath)
Write-Host ("sheet {0}x{1}, scale {2:N3}" -f $src.Width, $src.Height, $scale)

for ($i = 0; $i -lt $cells.Count; $i++) {
	$x0 = $cells[$i] * $cellSize

	# Painted bounds of this cell, so the figure is centred on its own art.
	$minX = $x0 + $cellSize
	$maxX = $x0 - 1
	for ($y = 0; $y -lt $cellSize; $y++) {
		for ($x = $x0; $x -lt $x0 + $cellSize; $x++) {
			if ($src.GetPixel($x, $y).A -gt 8) {
				if ($x -lt $minX) { $minX = $x }
				if ($x -gt $maxX) { $maxX = $x }
			}
		}
	}
	if ($maxX -lt $x0) {
		throw "cell $($cells[$i]) is empty"
	}

	$centerX = ($minX + $maxX + 1) / 2.0
	$destW = $cellSize * $scale
	$destX = [Math]::Round($canvasW / 2.0 - ($centerX - $x0) * $scale)
	# The sheet's ground line lands on the canvas ground line.
	$destY = [Math]::Round($groundY - $sheetGround * $scale)

	$frame = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
	$g = [System.Drawing.Graphics]::FromImage($frame)
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g.DrawImage(
		$src,
		(New-Object System.Drawing.Rectangle($destX, $destY, [Math]::Round($destW), [Math]::Round($destW))),
		(New-Object System.Drawing.Rectangle($x0, 0, $cellSize, $cellSize)),
		[System.Drawing.GraphicsUnit]::Pixel)
	$g.Dispose()

	$outPath = Join-Path $outDir ("slide_{0}.png" -f $i)
	$frame.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
	$frame.Dispose()
	Write-Host ("wrote {0} from cell {1} (x {2}..{3})" -f $outPath, $cells[$i], $minX, $maxX)
}

$src.Dispose()
Write-Host "done"
