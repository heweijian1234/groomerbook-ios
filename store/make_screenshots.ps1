Add-Type -AssemblyName System.Drawing
$W = 1290; $H = 2796
$OUT = 'E:\AI-Projects\个人成长\10-项目\SaaS项目\groomerbook-ios\store'
if (-not (Test-Path $OUT)) { New-Item -ItemType Directory -Force $OUT | Out-Null }

function New-Bg($w, $h, $c1, $c2, $c3, $c4) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb($c1,$c2,$c3), [System.Drawing.Color]::FromArgb($c2,$c3,$c4), 60)
    $g.FillRectangle($bg, $rect)
    return @($bmp, $g)
}
function CardSolid($g, $x, $y, $w, $h, $a, $r_, $gr, $b) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 44
    $path.AddArc($x, $y, $r, $r, 180, 90); $path.AddArc($x+$w-$r, $y, $r, $r, 270, 90)
    $path.AddArc($x+$w-$r, $y+$h-$r, $r, $r, 0, 90); $path.AddArc($x, $y+$h-$r, $r, $r, 90, 90)
    $path.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, $r_, $gr, $b))
    $g.FillPath($brush, $path)
}
function Txt($g, $t, $x, $y, $size, $bold, $r, $gr, $b) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $code = [int][char]$t[0]
    $fam = if ($code -ge 0xD800) { 'Segoe UI Emoji' } else { 'Segoe UI' }
    $font = New-Object System.Drawing.Font($fam, $size, $style)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($r, $gr, $b))
    $g.DrawString($t, $font, $brush, $x, $y)
}
function CenterTxt($g, $t, $y, $size, $bold, $r, $gr, $b) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($r, $gr, $b))
    $m = $g.MeasureString($t, $font)
    $x = ([single]($script:W) - $m.Width) / 2
    $g.DrawString($t, $font, $brush, $x, $y)
}

# ========== shot1 主张（暖橙渐变）==========
$c = New-Bg $W $H 250 120 40 210; $bmp = $c[0]; $g = $c[1]
CenterTxt $g 'GroomerBook' 150 66 $true 255 255 255
CenterTxt $g "Remember every dog. Win every rebook." 260 40 $false 255 220 180

CardSolid $g 130 420 1030 420 235 255 255 255
Txt $g 'Max - Poodle' 190 470 44 $true 60 40 30
Txt $g 'Recipe: #10 blade - oatmeal shampoo' 190 545 36 $false 90 80 70
Txt $g 'Loves: chicken jerky - chin rubs' 190 610 36 $false 90 80 70
Txt $g 'Bite risk: SAFE' 190 675 36 $true 20 130 80
Txt $g 'Bring: large dryer' 190 740 36 $false 200 100 20

CardSolid $g 130 890 1030 340 230 255 255 255
Txt $g 'Sarah Miller' 190 940 44 $true 60 40 30
Txt $g '12 Oak St - (555) 010-2288' 190 1015 36 $false 90 80 70
Txt $g 'Husband opens gate - 2 no-shows' 190 1080 36 $false 90 80 70
Txt $g 'Consider a deposit' 190 1145 36 $true 200 100 20

CardSolid $g 130 1280 1030 340 244 100 60 255
Txt $g "Today's visit" 190 1330 40 $true 255 230 200
Txt $g 'Max - 90 min - Navigate' 190 1400 40 $false 255 255 255
Txt $g 'Bring: large dryer' 190 1465 36 $false 255 210 180

CenterTxt $g 'No account. No cloud. Offline.' 1750 42 $true 255 220 180
$bmp.Save("$OUT\shot1.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# ========== shot2 狗档案详情 ==========
$c = New-Bg $W $H 255 250 245 240; $bmp = $c[0]; $g = $c[1]
Txt $g 'Max' 80 130 64 $true 60 40 30
Txt $g 'Poodle - 12 kg - 90 min groom' 82 230 36 $false 120 100 80

CardSolid $g 70 320 ($W-140) 420 255 255 255 255
Txt $g 'GROOMING RECIPE' 120 360 36 $true 230 120 40
Txt $g '#10 blade body - #15 face' 120 430 38 $false 60 50 40
Txt $g 'Oatmeal shampoo - teddy bear style' 120 495 38 $false 60 50 40
Txt $g 'Written once. Reused every visit.' 120 570 30 $false 150 140 120

CardSolid $g 70 790 ($W-140) 420 255 255 255 255
Txt $g 'HEALTH & TEMPERAMENT' 120 830 36 $true 230 120 40
Txt $g 'Bite risk: Safe' 120 900 38 $false 20 130 80
Txt $g 'Vaccine: valid thru Jun 2027' 120 965 38 $false 20 130 80
Txt $g 'Shy with strangers' 120 1030 38 $false 60 50 40
Txt $g 'Bring: large dryer' 120 1095 38 $true 200 100 20

CardSolid $g 70 1260 ($W-140) 380 255 255 255 255
Txt $g 'WHAT MAX LOVES' 120 1300 36 $true 230 120 40
Txt $g 'Treats: chicken jerky' 120 1370 38 $false 60 50 40
Txt $g 'Petting: chin rubs' 120 1435 38 $false 60 50 40

CenterTxt $g 'Win them over, every visit' 1720 44 $true 230 120 40
$bmp.Save("$OUT\shot2.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# ========== shot3 预约+提醒 ==========
$c = New-Bg $W $H 40 24 60 90; $bmp = $c[0]; $g = $c[1]
CenterTxt $g 'Never miss a rebook' 150 58 $true 255 255 255
CenterTxt $g 'Reminders, deposits, done-for-you reports' 250 36 $false 255 210 170

CardSolid $g 130 420 1030 500 235 255 255 255
Txt $g 'Sarah Miller' 190 470 46 $true 60 40 30
Txt $g 'Max - 90 min - 15 min buffer' 190 545 36 $false 90 80 70
Txt $g 'Reminder 6h before' 190 615 36 $true 60 110 220
Txt $g 'Reminder 2h before' 190 680 36 $true 60 110 220
Txt $g 'Reminder 1h before' 190 745 36 $true 60 110 220
Txt $g '3 no-shows on record' 190 820 34 $true 220 90 30

CardSolid $g 130 980 1030 200 244 120 60 255
Txt $g 'Consider a deposit' 190 1030 40 $true 255 240 220
Txt $g 'Flagged automatically from history' 190 1095 34 $false 255 210 180

CardSolid $g 130 1240 1030 460 235 255 255 255
Txt $g 'THIS MONTH' 190 1285 36 $true 230 120 40
Txt $g 'Visits: 18' 190 1355 42 $false 60 50 40
Txt $g 'Revenue: $1,620' 190 1425 42 $false 60 50 40
Txt $g 'Mileage: 212 mi (tax deduction)' 190 1495 42 $false 60 50 40

CenterTxt $g 'Export - Offline - Free' 1780 44 $true 255 210 170
$bmp.Save("$OUT\shot3.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
Write-Output 'DONE 3 shots (GroomerBook EN v2)'
