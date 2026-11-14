# Shared by the whole-run suites of tools/run-game-tests.ps1 (RunGameTests*.Tests.ps1): a fake game
# that writes a prepared debuglog.txt instead of playing the tests, and a sandbox with a fake X4
# install and test profile. In a release session the fake game writes $FAKE_SOURCE_LOG.new, .load or
# .unload instead, by whether the installed release extension loads a save and whether the game
# tests' extension is installed with it (only with the mod), and keeps copies of what that
# session saw: the profile's content.xml ($FAKE_ARGS.<kind>.xml) and, when the game tests'
# extension is installed, $FAKE_MARK.<kind> and its autostart and harness ($FAKE_ARGS.<kind>.autostart,
# .harness). Dot-source it from BeforeAll, after TestHelpers.ps1.

# Lines as X4 writes them: MD debug_text under [Scripts], Lua DebugError under [=ERROR=]
$script:PassingLog = @(
    '[General] 0.00 ======================================'
    '[=ERROR=] 2.50 [apirateslife-test] autostart: starting gamestart apirateslife_test'
    "[Init   ] 0.00 Starting new game using gamestart 'apirateslife_test' in 9.00 (611726)"
    '[General] 3.10 Could not find signature file extensions\apirateslife\md\apirateslife_bail.xml.sig'
    '[General] 3.11 Failed to verify the file signature for file extensions\apirateslife\md\apirateslife_bail.xml (error: 14)'
    "[FileIO ] 3.12 File I/O: Failed to verify the file signature for file '.\extensions\starwarsmod_m1\libraries\icons.xml' (error: 14)"
    "[FileIO ] 3.13 File I/O: Failed to verify the file signature for file '.\extensions\apirateslife\libraries\icons.xml' (error: 14)"
    '[Scripts] 40.01 *** Context:md.APiratesLife_Tests.Run<inst:2a1b>: [apirateslife-test] RUN START 2 tests'
    '[Scripts] 40.02 *** Context:md.APiratesLife_Bail.AdjustEjectChance: [apirateslife] bail check: null attacking null: chance 30 -> 60'
    '[Scripts] 40.03 *** Context:md.APiratesLife_Tests.Report<inst:2a1c>: [apirateslife-test] PASS fixture_test_a: 5 cases'
    '[Scripts] 44.00 *** Context:md.APiratesLife_Tests.Report<inst:2a1d>: [apirateslife-test] PASS fixture_test_b: hull 100%, 4 equipment kept, pilot skill 38'
    '[Scripts] 44.01 *** Context:md.APiratesLife_Tests.NextTest<inst:2a1e>: [apirateslife-test] DONE passed=2 failed=0'
)

function New-FakeGame([string] $Dir) {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    if ($script:OnWindows) {
        $game = Join-Path $Dir 'fakegame.cmd'
        $body = @'
@echo off
echo %*>"%FAKE_ARGS%"
if exist "%FAKE_X4%\extensions\apirateslife_tests\content.xml" echo installed>"%FAKE_MARK%"
if exist "%FAKE_X4%\game.lock" copy /y "%FAKE_X4%\game.lock" "%FAKE_LOCKSEEN%" >nul
if defined FAKE_HANG ping -n 20 127.0.0.1 >nul
set "LOG=%FAKE_SOURCE_LOG%"
set "REL=%FAKE_X4%\extensions\apirateslife_release_tests\ui\apirateslife_release_tests.lua"
if not exist "%REL%" goto play
set KIND=new
findstr /b /c:"local session = { load" "%REL%" >nul && set KIND=load
if "%KIND%"=="load" if not exist "%FAKE_X4%\extensions\apirateslife_tests\content.xml" set KIND=unload
set "LOG=%FAKE_SOURCE_LOG%.%KIND%"
for %%F in ("%FAKE_LOGPATH%") do copy /y "%%~dpFcontent.xml" "%FAKE_ARGS%.%KIND%.xml" >nul
if exist "%FAKE_X4%\extensions\apirateslife_tests\content.xml" echo installed>"%FAKE_MARK%.%KIND%"
if exist "%FAKE_X4%\extensions\apirateslife_tests\content.xml" copy /y "%FAKE_X4%\extensions\apirateslife_tests\ui\apirateslife_tests_autostart.lua" "%FAKE_ARGS%.%KIND%.autostart" >nul
if exist "%FAKE_X4%\extensions\apirateslife_tests\content.xml" copy /y "%FAKE_X4%\extensions\apirateslife_tests\md\apirateslife_tests.xml" "%FAKE_ARGS%.%KIND%.harness" >nul
:play
copy /y "%LOG%" "%FAKE_LOGPATH%" >nul
'@
        Set-Content $game ($body -replace "`r?`n", "`r`n") -Encoding Ascii
    }
    else {
        $game = Join-Path $Dir 'fakegame'
        Write-LfFile $game @'
#!/bin/sh
echo "$*" > "$FAKE_ARGS"
[ -f "$FAKE_X4/extensions/apirateslife_tests/content.xml" ] && echo installed > "$FAKE_MARK"
[ -f "$FAKE_X4/game.lock" ] && cp "$FAKE_X4/game.lock" "$FAKE_LOCKSEEN"
# exec, so closing the game kills the sleep too and nothing keeps the output open
[ -n "$FAKE_HANG" ] && exec sleep 20
log="$FAKE_SOURCE_LOG"
# A release session (-Release): its own log, and a copy of what it saw, by whether it loads a save
rel="$FAKE_X4/extensions/apirateslife_release_tests/ui/apirateslife_release_tests.lua"
if [ -f "$rel" ]; then
    kind=new
    tests="$FAKE_X4/extensions/apirateslife_tests"
    grep -q '^local session = { load' "$rel" && kind=load
    [ "$kind" = load ] && [ ! -f "$tests/content.xml" ] && kind=unload
    log="$FAKE_SOURCE_LOG.$kind"
    cp "$(dirname "$FAKE_LOGPATH")/content.xml" "$FAKE_ARGS.$kind.xml"
    if [ -f "$tests/content.xml" ]; then
        echo installed > "$FAKE_MARK.$kind"
        cp "$tests/ui/apirateslife_tests_autostart.lua" "$FAKE_ARGS.$kind.autostart"
        cp "$tests/md/apirateslife_tests.xml" "$FAKE_ARGS.$kind.harness"
    fi
fi
cp "$log" "$FAKE_LOGPATH"
'@
        & chmod +x $game
    }
    $game
}

# The sandbox for one test, as script variables the tests read: $root, $x4, $profiles,
# $profileDir, $contentXml, $report, $markdown, $game and $runArgs
function New-RunSandbox {
    $script:root = New-TestDir
    $script:x4 = Join-Path $root 'x4'
    Write-LfFile "$x4/extensions/apirateslife/content.xml" '<content id="apirateslife"/>'
    Write-LfFile "$x4/extensions/starwarsmod_m1/content.xml" '<content id="SW Interworlds" enabled="0"/>'
    # The test profile, under X4_PROFILE_ROOT, with the extensions the run needs switched on
    $script:profiles = Join-Path $root 'profiles'
    $script:profileDir = Join-Path $profiles '90000301'
    $script:contentXml = Join-Path $profileDir 'content.xml'
    Write-LfFile $contentXml @'
<?xml version="1.0" encoding="utf-8"?>
<content>
  <extension id="SW Interworlds" enabled="true"/>
  <extension id="apirateslife" enabled="true"/>
</content>
'@
    $env:X4_PROFILE_ROOT = $profiles
    $env:FAKE_X4 = $x4
    $env:FAKE_MARK = Join-Path $root 'installed.txt'
    $env:FAKE_ARGS = Join-Path $root 'args.txt'
    $env:FAKE_LOCKSEEN = Join-Path $root 'lock-seen.txt'
    $env:FAKE_SOURCE_LOG = Join-Path $root 'source.log'
    $env:FAKE_LOGPATH = Join-Path $profileDir 'debuglog.txt'
    $env:FAKE_HANG = $null
    $script:report = Join-Path $root 'results.xml'
    $script:game = New-FakeGame (Join-Path $root 'bin')
    $script:markdown = Join-Path $root 'report.md'
    $script:runArgs = @('-X4Path', $x4, '-ProfileId', '90000301', '-GameExe', $game, '-ReportPath', $report, '-MarkdownPath', $markdown,
                        '-PollSeconds', '0.2', '-Commit', '0123456789abcdef0123456789abcdef01234567', '-Branch', 'feature/x')
}

function Remove-RunSandbox {
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($v in 'X4_PROFILE_ROOT', 'FAKE_X4', 'FAKE_MARK', 'FAKE_ARGS', 'FAKE_LOCKSEEN', 'FAKE_SOURCE_LOG', 'FAKE_LOGPATH', 'FAKE_HANG') { Remove-Item "env:$v" -ErrorAction SilentlyContinue }
}
