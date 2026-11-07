Add-Type -AssemblyName System.Drawing
$S = 1024
$OUT = 'E:\AI-Projects\个人成长\10-项目\SaaS项目\groomerbook-ios\GroomerBook\Assets.xcassets\AppIcon.appiconset\AppIcon1024.png'

$bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'

# 橙棕暖渐变底（宠物主题）
$rect = New-Object System.Drawing.Rectangle(0, 0, $S, $S)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
    [System.Drawing.Color]::FromArgb(255, 250, 150, 60),
    [System.Drawing.Color]::FromArgb(255, 200, 90, 40), 60)
$g.FillRectangle($bg, $rect)

# 白色圆角爪印（四趾+掌心）
$white = [System.Drawing.Brushes]::White
# 掌心
$g.FillEllipse($white, 330, 520, 360, 330)
# 四个趾
$g.FillEllipse($white, 200, 350, 150, 190)
$g.FillEllipse($white, 400, 300, 150, 190)
$g.FillEllipse($white, 600, 320, 150, 190)
$g.FillEllipse($white, 740, 430, 130, 170)

# 底部小剪刀元素（美容暗示）：两条白线交叉
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 90, 45), 28)
$g.DrawLine($pen, 620, 800, 830, 950)
$g.DrawLine($pen, 830, 800, 620, 950)

$bmp.Save($OUT, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
$img = [System.Drawing.Image]::FromFile($OUT)
Write-Output "icon saved: $($img.Width)x$($img.Height)"
$img.Dispose()
