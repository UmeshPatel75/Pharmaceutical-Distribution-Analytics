# =============================================================
#  Export the eight anon.* views to CSV.
#
#  Run in PowerShell (not Command Prompt).
#  If Invoke-Sqlcmd is not recognised, install the module first:
#      Install-Module -Name SqlServer -Scope CurrentUser -Force
#
#  If the server name is wrong you will get a connection error.
#  Your instance path was MSSQL16.MSSQL2022, so the instance is
#  MSSQL2022. Try "localhost\MSSQL2022" first; if that fails try
#  ".\MSSQL2022" or just "localhost".
# =============================================================

$server   = "localhost\MSSQL2022"
$database = "ATUL202021"
$outDir   = "C:\Users\Umesh Patel\Downloads\atul_pharma\data\raw"

$views = @(
    "fact_sales",
    "dim_customer",
    "dim_product",
    "fact_stock",
    "fact_purchase",
    "fact_shortage",
    "fact_ageing",
    "fact_expiry_returns"
)

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Write-Host "Exporting to $outDir`n" -ForegroundColor Cyan

foreach ($v in $views) {
    $path = Join-Path $outDir "$v.csv"
    Write-Host ("{0,-22}" -f $v) -NoNewline
    try {
        $rows = Invoke-Sqlcmd `
            -ServerInstance $server `
            -Database $database `
            -Query "SELECT * FROM anon.$v" `
            -MaxCharLength 1000000 `
            -QueryTimeout 600 `
            -TrustServerCertificate

        $rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-Host ("{0,10:N0} rows" -f $rows.Count) -ForegroundColor Green
    }
    catch {
        Write-Host "FAILED" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

Write-Host "`nDone. Files in $outDir" -ForegroundColor Cyan
Write-Host "Do NOT export anon.CustomerMap or anon.SupplierMap." -ForegroundColor Yellow
