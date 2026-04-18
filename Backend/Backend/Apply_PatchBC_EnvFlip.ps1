Set-StrictMode -Version Latest
$BackendRoot  = "D:\Tajir\Backend"
$FrontendRoot = "D:\Tajir\Frontend"

function Backup-File { param([string]$Path); Copy-Item $Path "$Path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
function Append-IfAbsent {
    param([string]$FilePath,[string]$Guard,[string]$Block)
    $c = Get-Content $FilePath -Raw
    if ($c -match [regex]::Escape($Guard)) { Write-Host "  [SKIP] $(Split-Path $FilePath -Leaf)" -ForegroundColor Yellow; return }
    Backup-File $FilePath
    Add-Content $FilePath $Block -Encoding UTF8
    Write-Host "  [DONE] $(Split-Path $FilePath -Leaf)" -ForegroundColor Green
}

Write-Host "PATCH B - config..." -ForegroundColor Cyan
$configCandidates = @("$BackendRoot\app\config\index.py","$BackendRoot\app\config.py","$BackendRoot\app\validate_env.py","$BackendRoot\app\core\config.py")
$configPath = $null
foreach ($c in $configCandidates) { if (Test-Path $c) { $configPath = $c; break } }
if (-not $configPath) {
    $configPath = "$BackendRoot\app\config\index.py"
    $d = Split-Path $configPath -Parent
    if (-not (Test-Path $d)) { New-Item -ItemType Directory $d | Out-Null }
    New-Item -ItemType File $configPath | Out-Null
    Write-Host "  [NEW] $configPath" -ForegroundColor Cyan
}
$patchB = "`n# -- Patch B --`nimport os as _os`nFOREX_API_KEYS_REQUIRED = ['TWELVE_DATA_API_KEY','FCS_API_KEY','FOREXRATEAPI_API_KEY','EXCHANGERATESAPI_API_KEY','ITICK_API_KEY','FINNHUB_KEY','DEEPSEEK_API_KEY']`ndef startup_snapshot_phase14():`n    return {'forex_providers_configured':sum(1 for k in ['TWELVE_DATA_API_KEY','FCS_API_KEY','FOREXRATEAPI_API_KEY','EXCHANGERATESAPI_API_KEY','ITICK_API_KEY','FINNHUB_KEY'] if _os.getenv(k,'').strip()),'deepseek_configured':bool(_os.getenv('DEEPSEEK_API_KEY','').strip()),'ai_routes_enabled':_os.getenv('AI_ROUTES_AVAILABLE','false').lower() in {'true','1','yes'}}`ndef validate_forex_env(raise_on_missing=False):`n    missing=[k for k in FOREX_API_KEYS_REQUIRED if not _os.getenv(k,'').strip()]`n    if raise_on_missing and missing: raise ValueError(f'Missing: {missing}')`n    return missing`n# -- End Patch B --"
Append-IfAbsent $configPath "startup_snapshot_phase14" $patchB

Write-Host "PATCH C - api_service.dart..." -ForegroundColor Cyan
$dartPath = "$FrontendRoot\lib\services\api_service.dart"
if (-not (Test-Path $dartPath)) { Write-Host "  [ERROR] Not found: $dartPath" -ForegroundColor Red }
else {
    $dartContent = Get-Content $dartPath -Raw
    if ($dartContent -match "aiChat\(") { Write-Host "  [SKIP] already patched" -ForegroundColor Yellow }
    else {
        Backup-File $dartPath
        $newMethods = "`n  // Patch C`n  Future<Map<String,dynamic>> aiChat(List<Map<String,dynamic>> messages,{Map<String,dynamic>? userContext}) async => await _post('/api/v1/ai/chat',{'messages':messages,if(userContext!=null)'user_context':userContext});`n  Future<Map<String,dynamic>> aiAnalyzeMarket(String pair,{String timeframe='1h',bool includeNews=true}) async => await _post('/api/v1/ai/analyze',{'pair':pair,'timeframe':timeframe,'include_news':includeNews});`n  Future<Map<String,dynamic>> aiGenerateSignal(String pair,{String timeframe='1h'}) async => await _post('/api/v1/ai/signal',{'pair':pair,'timeframe':timeframe});`n  Future<Map<String,dynamic>> aiRiskCheck({required String pair,required String direction,required double entryPrice,required double stopLoss,required double takeProfit,required double lotSize,required double accountBalance}) async => await _post('/api/v1/ai/risk',{'pair':pair,'direction':direction,'entry_price':entryPrice,'stop_loss':stopLoss,'take_profit':takeProfit,'lot_size':lotSize,'account_balance':accountBalance});`n  Future<Map<String,dynamic>> aiNewsImpact(List<String> headlines,String pair) async => await _post('/api/v1/ai/news-impact',{'headlines':headlines,'pair':pair});`n  Future<Map<String,dynamic>> aiAutonomousBriefing({List<String> pairs=const['EUR/USD','GBP/USD','USD/JPY'],String stage='monitoring',String? userInstruction}) async => await _post('/api/v1/ai/briefing',{'pairs':pairs,'stage':stage,if(userInstruction!=null)'user_instruction':userInstruction});`n  Future<Map<String,dynamic>> getForexRates([List<String>? pairs]) async => await _get('/api/v1/market/rates'+(pairs!=null?'?pairs='+pairs.join(','):''));`n  Future<Map<String,dynamic>> getMarketSnapshot([List<String>? pairs]) async => await _get('/api/v1/market/snapshot'+(pairs!=null?'?pairs='+pairs.join(','):''));`n  Future<Map<String,dynamic>> getOHLC(String pair,{String interval='1h',int outputsize=100}) async => await _get('/api/v1/market/ohlc?pair='+Uri.encodeComponent(pair)+'&interval='+interval+'&outputsize='+outputsize.toString());`n  Future<Map<String,dynamic>> getForexNews({String? pair,int limit=10}) async => await _get('/api/v1/market/news?limit='+limit.toString()+(pair!=null?'&pair='+Uri.encodeComponent(pair):''));`n  Future<Map<String,dynamic>> getForexSentiment([String? pair]) async => await _get('/api/v1/market/sentiment'+(pair!=null?'?pair='+Uri.encodeComponent(pair):''));`n  Future<Map<String,dynamic>> getIndicators(String pair,{String indicator='rsi',String interval='1h',int period=14}) async => await _get('/api/v1/market/indicators?pair='+Uri.encodeComponent(pair)+'&indicator='+indicator+'&interval='+interval+'&period='+period.toString());`n  Future<Map<String,dynamic>> getForexApiHealth() async => await _get('/api/v1/market/forex-health');`n  Future<Map<String,dynamic>> getAIHealth() async => await _get('/api/v1/ai/health');`n  // End Patch C`n"
        $lastBrace = $dartContent.LastIndexOf('}')
        $patched = $dartContent.Substring(0,$lastBrace) + $newMethods + $dartContent.Substring($lastBrace)
        Set-Content $dartPath $patched -Encoding UTF8
        Write-Host "  [DONE] api_service.dart patched" -ForegroundColor Green
    }
}

Write-Host "ENV flip..." -ForegroundColor Cyan
$envPath = @("$BackendRoot\.env","$BackendRoot\app\.env","$BackendRoot\.env.local") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($envPath) {
    $ec = Get-Content $envPath -Raw
    if ($ec -match "AI_ROUTES_AVAILABLE=true") { Write-Host "  [SKIP] already true" -ForegroundColor Yellow }
    else { Backup-File $envPath; (Get-Content $envPath -Raw) -replace "AI_ROUTES_AVAILABLE\s*=\s*false","AI_ROUTES_AVAILABLE=true" | Set-Content $envPath -Encoding UTF8; Write-Host "  [DONE] .env updated" -ForegroundColor Green }
} else { Write-Host "  [INFO] No .env found - set AI_ROUTES_AVAILABLE=true in Railway" -ForegroundColor Yellow }

Write-Host "=== Verify ===" -ForegroundColor Cyan
if ((Get-Content $configPath -Raw) -match "startup_snapshot_phase14") { Write-Host "  [OK] Patch B" -ForegroundColor Green } else { Write-Host "  [FAIL] Patch B" -ForegroundColor Red }
if (Test-Path $dartPath) { $dc = Get-Content $dartPath -Raw; if ($dc -match "aiChat\(" -and $dc -match "getForexRates\(") { Write-Host "  [OK] Patch C" -ForegroundColor Green } else { Write-Host "  [FAIL] Patch C" -ForegroundColor Red } }
Write-Host "Done. Now: git add -A, commit, push" -ForegroundColor Cyan
