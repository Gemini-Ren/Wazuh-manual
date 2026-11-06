@echo off
setlocal

:: ===== Auto-elevacao: se nao for admin, reabre como administrador e encerra =====
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ===== Log (a janela fecha sozinha, entao o resultado fica registrado aqui) =====
set "LOG=%SystemRoot%\Temp\wazuh_remote_commands.log"
call :main > "%LOG%" 2>&1
exit /b %errorlevel%


:main
echo ===== %date% %time% =====

:: ===== Localiza a pasta do agente =====
set "AGENT_DIR=%ProgramFiles(x86)%\ossec-agent"
if not exist "%AGENT_DIR%\ossec.conf" set "AGENT_DIR=%ProgramFiles%\ossec-agent"
if not exist "%AGENT_DIR%\ossec.conf" goto :sem_agente

set "INTERNAL=%AGENT_DIR%\internal_options.conf"
set "LOCAL=%AGENT_DIR%\local_internal_options.conf"
echo Pasta do agente: %AGENT_DIR%

:: ===== Backup =====
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
if exist "%INTERNAL%" copy /y "%INTERNAL%" "%INTERNAL%.%TS%.bak" >nul
if exist "%LOCAL%" copy /y "%LOCAL%" "%LOCAL%.%TS%.bak" >nul
echo Backups criados com sufixo .%TS%.bak

:: ===== internal_options.conf: altera 0 para 1 =====
if not exist "%INTERNAL%" goto :sem_internal
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f='%INTERNAL%'; $c=@(Get-Content -LiteralPath $f); if ($c -match '^\s*logcollector\.remote_commands\s*=') { $c = $c -replace '^\s*logcollector\.remote_commands\s*=.*$','logcollector.remote_commands=1'; Set-Content -LiteralPath $f -Value $c -Encoding ASCII; exit 0 } else { exit 2 }"
if %errorlevel% equ 2 echo [AVISO] Linha nao encontrada em internal_options.conf
if %errorlevel% equ 0 echo [OK] internal_options.conf atualizado
goto :local

:sem_internal
echo [AVISO] internal_options.conf nao encontrado, pulando.

:: ===== local_internal_options.conf: adiciona ou altera =====
:local
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f='%LOCAL%'; if (Test-Path -LiteralPath $f) { $c=@(Get-Content -LiteralPath $f) } else { $c=@() }; if ($c -match '^\s*logcollector\.remote_commands\s*=') { $c = $c -replace '^\s*logcollector\.remote_commands\s*=.*$','logcollector.remote_commands=1' } else { $c += 'logcollector.remote_commands=1' }; Set-Content -LiteralPath $f -Value $c -Encoding ASCII"
if %errorlevel% equ 0 (echo [OK] local_internal_options.conf atualizado) else (echo [ERRO] Falha ao atualizar local_internal_options.conf)

:: ===== Reinicia o servico =====
set "SVC=WazuhSvc"
sc query "%SVC%" >nul 2>&1
if %errorlevel% neq 0 set "SVC=OssecSvc"
echo Reiniciando o servico %SVC%...
net stop "%SVC%"
net start "%SVC%"
if %errorlevel% neq 0 echo [ERRO] Nao foi possivel iniciar o servico %SVC%. Verifique o ossec.log.

:: ===== Conferencia =====
echo ===== Resultado =====
echo internal_options.conf:
findstr /b /c:"logcollector.remote_commands" "%INTERNAL%"
echo local_internal_options.conf:
findstr /b /c:"logcollector.remote_commands" "%LOCAL%"
exit /b 0

:sem_agente
echo [ERRO] Agente Wazuh nao encontrado em Program Files nem Program Files (x86).
exit /b 1
