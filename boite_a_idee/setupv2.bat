@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Vérifier que docker est installé
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Docker n'est pas installe ou pas dans le PATH. Veuillez l'installer.
    exit /b 1
)

REM Vérifier que docker-compose est installé
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Docker-compose n'est pas installe ou pas dans le PATH. Veuillez l'installer.
    exit /b 1
)

REM Définir les noms des conteneurs et images à nettoyer avant de relancer
set "containers=myprojectdocker-db-1,myprojectdocker-dev-1,myprojectdocker-test-1,pma_container"
set "images=geircode/string_to_hex,myprojectdocker_dev,myprojectdocker_test,mysql"

REM Nettoyage des conteneurs existants
for %%c in (%containers%) do (
    docker stop %%c >nul 2>&1
    docker rm %%c >nul 2>&1
)

REM Nettoyage des images existantes
for %%i in (%images%) do (
    docker rmi %%i -f >nul 2>&1
)

REM Nom du projet docker-compose
set "PROJECT_NAME=myprojectdocker"

REM Création du dossier test_results s'il n'existe pas
if not exist "test_results" (
    mkdir test_results
)

REM Vérifier l'existence d'un fichier .csproj
dir *.csproj /b > csproj_list.txt
for /f "delims=" %%I in (csproj_list.txt) do (
    set "CSPROJ_NAME=%%I"
    goto found_csproj
)

echo Aucun fichier .csproj trouvé dans ce répertoire.
del csproj_list.txt
exit /b 1

:found_csproj
del csproj_list.txt

REM Extraire la version .NET du projet
set "DOTNET_VERSION="
for /f "tokens=3 delims=<>" %%a in ('findstr /i "<TargetFramework>" %CSPROJ_NAME%') do (
    set "DOTNET_VERSION=%%a"
)

if "%DOTNET_VERSION%"=="" (
    echo Impossible de determiner la version .NET du projet.
    exit /b 1
)

REM Extraire le numéro de version (net6.0 => 6.0)
set "DOTNET_SDK_VERSION="
for /f "tokens=* delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-" %%v in ("%DOTNET_VERSION%") do set "DOTNET_SDK_VERSION=%%v"

if "%DOTNET_SDK_VERSION%"=="" (
    echo Impossible de determiner la version du SDK .NET.
    exit /b 1
)

echo Generation du docker-compose.yaml...

REM Génération du docker-compose.yaml
(
echo version: '3.8'
echo services:
echo   db:
echo     image: mysql:latest
echo     environment:
echo       MYSQL_ROOT_PASSWORD: root
echo       MYSQL_DATABASE: mydatabase
echo     ports:
echo       - '3306:3306'
echo     volumes:
echo       - db-data:/var/lib/mysql
echo   dev:
echo     build:
echo       context: .
echo       dockerfile: Dockerfile
echo       target: development
echo     ports:
echo       - '9721:80'  
echo       - '443:443'
echo     volumes:
echo       - .:/app
echo     depends_on:
echo       - db
echo   test:
echo     build:
echo       context: ..
echo       dockerfile: Dockerfile.test
echo     depends_on:
echo       - db
echo     volumes:
echo       - ../test:/app/test
echo       - ./test_results:/app/test_results
echo   phpmyadmin:
echo     image: phpmyadmin:5.2.0
echo     container_name: pma_container
echo     links:
echo       - db
echo     environment:
echo       PMA_HOST: db
echo       PMA_PORT: 3306
echo       PMA_ARBITRARY: 1
echo     restart: always
echo     ports:
echo       - 8083:80
echo volumes:
echo   db-data:
echo networks:
echo   default:
) > docker-compose.yaml

REM Recherché un .exe existant n'a plus trop d'importance, on va le construire dans le conteneur
REM On part du principe que le docker build/publish sera fait dans le Dockerfile
REM On copie le .csproj et fait le publish dans le Dockerfile directement.

echo Generation du Dockerfile de dev...

(
echo # Stage 1: build du projet
echo FROM mcr.microsoft.com/dotnet/sdk:%DOTNET_SDK_VERSION% AS build
echo WORKDIR /app
echo COPY ./%CSPROJ_NAME% ./
echo RUN dotnet restore ./%CSPROJ_NAME%
echo COPY . .
echo RUN dotnet publish ./%CSPROJ_NAME% -c Release -o out
echo
echo # Stage 2: Image de dev
echo FROM mcr.microsoft.com/dotnet/sdk:%DOTNET_SDK_VERSION% AS development
echo WORKDIR /app
echo COPY --from=build /app/out .
echo # Installation des outils utiles (sudo, xdg-utils, iproute2 pour ss, netstat)
echo RUN apt-get update && apt-get install -y sudo xdg-utils iproute2 coreutils
echo # On expose le port 80 et 443
echo EXPOSE 80
echo EXPOSE 443
echo # Développement : on utilise dotnet watch pour recompiler et relancer à chaud
echo ENTRYPOINT ["dotnet", "watch", "--project", "%CSPROJ_NAME%"]
echo
echo # Stage 3: Image de production
echo FROM mcr.microsoft.com/dotnet/aspnet:%DOTNET_SDK_VERSION% AS production
echo WORKDIR /app
echo COPY --from=build /app/out .
echo EXPOSE 80
echo RUN dotnet dev-certs https
echo ENTRYPOINT ["dotnet", "%~nCSPROJ_NAME%.dll"]
) > Dockerfile

echo Generation du Dockerfile de test...

(
echo # syntax=docker/dockerfile:1
echo FROM mcr.microsoft.com/dotnet/sdk:%DOTNET_SDK_VERSION% AS build
echo WORKDIR /app
echo # On suppose que le repertoire parent (..) contient le code source de l'application et le dossier test
echo COPY %~nCSPROJ_NAME%/ ./%~nCSPROJ_NAME%/
echo COPY test/ ./test/
echo RUN dotnet restore %~nCSPROJ_NAME%/%CSPROJ_NAME%
echo RUN dotnet build %~nCSPROJ_NAME%/%CSPROJ_NAME% -c Release
echo RUN dotnet restore test/test.csproj
echo RUN dotnet build test/test.csproj -c Release
echo WORKDIR /app/test
echo # On execute les tests
echo CMD ["dotnet", "test", "test.csproj", "--logger", "trx;LogFileName=test_results.trx", "--results-directory", "/app/test_results"]
) > ../Dockerfile.test

REM Générer le lunch.sh (pas forcement utile sous Windows, mais conservé)
(
echo #!/bin/bash
echo dotnet dev-certs https
echo echo ""
echo echo "Installation de dependances dans le conteneur"
echo # On l'a deja fait dans le Dockerfile
echo echo "xdg-open 'https://localhost:7218'"
echo echo "Lancement de dotnet run dans le conteneur: utiliser docker-compose up dev"
) > ./lunch.sh

REM Démarrage des services
docker-compose -p %PROJECT_NAME% up -d --build

set CONTAINER_NAME=%PROJECT_NAME%-dev-1

REM Convertir le nom du conteneur en hex via geircode/string_to_hex (reconstruction de l'image si absente)
docker pull geircode/string_to_hex >nul 2>&1
docker run --rm geircode/string_to_hex bash string_to_hex.bash "%CONTAINER_NAME%" > vscode_remote_hex.txt

set /p VSCODE_REMOTE_HEX=<vscode_remote_hex.txt

REM Récupérer l'IP de la DB
for /f "delims=" %%i in ('docker inspect -f "{{.NetworkSettings.Networks.%PROJECT_NAME%_default.IPAddress}}" %PROJECT_NAME%-db-1') do set DB_IP=%%i

echo IP de la DB: %DB_IP%

REM Ouvrir localhost:5025 (il faut s'assurer qu'un service écoute sur ce port)
start http://localhost:5025/

REM Ouvrir VSCode dans le conteneur (il faut VSCode et l'extension Remote - Containers installée)
code --folder-uri=vscode-remote://attached-container+%VSCODE_REMOTE_HEX%/app

REM Nettoyer le fichier temporaire
del vscode_remote_hex.txt

echo Tout est lance. Appuyez sur une touche pour continuer...
pause

endlocal
