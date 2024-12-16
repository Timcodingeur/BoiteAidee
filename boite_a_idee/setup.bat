@echo off
setlocal
REM script permettant de créer des conteneurs docker dynamiquement, les versions et noms de fichiers ne sont pas codés en dur pour détecter ce que vous avez et ce dont vous avez besoin
set "containers=myprojectdocker-db-1,myprojectdocker-dev-1,myprojectdocker-test-1,pma_container"
set "images=geircode/string_to_hex,myprojectdocker_dev,myprojectdocker_test,mysql"
 
for %%c in (%containers%) do (
    docker stop %%c
    docker rm %%c
)
 
for %%i in (%images%) do (
    docker rmi %%i
)
REM Définir le nom du projet
set "PROJECT_NAME=myprojectdocker"

REM Vérifier si le répertoire test_results existe, si il existe pas il le créé
if not exist "test_results" (
    mkdir test_results
)

REM Création du fichier docker-compose.yaml
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
echo        image: phpmyadmin:5.2.0
echo        container_name: pma_container
echo        links:
echo            - db
echo        environment:
echo            PMA_HOST: db
echo            PMA_PORT: 3306
echo            PMA_ARBITRARY: 1
echo        restart: always
echo        ports:
echo            - 8083:80
echo volumes:
echo   db-data:
echo networks:
echo   default:
) > docker-compose.yaml

REM Vérifier l'existence de fichiers .csproj
if not exist "*.csproj" (
    echo Aucun fichier .csproj trouvé dans ce répertoire.
    exit /b
)

REM Trouver le fichier .csproj
for /F "delims=" %%I in ('dir *.csproj /b /a-d') do (
    set "CSPROJ_NAME=%%I"
    goto read_version
)

:read_version
REM Trouver la version de .NET
for /f "tokens=3 delims=<>" %%a in ('findstr /i "<TargetFramework>" %CSPROJ_NAME%') do (
    set "DOTNET_VERSION=%%a"
    REM enlever le "net" de la version
    for /f "tokens=* delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-" %%v in ("%%a") do set "DOTNET_SDK_VERSION=%%v"
    goto find_exe
)

:find_exe
REM tester s'il y a un .exe
if not exist "bin\Debug\%DOTNET_VERSION%\*.exe" (
    echo Aucun fichier .exe trouvé dans bin\Debug\%DOTNET_VERSION%\. Assurez-vous de compiler le projet.
    exit /b
)

REM Trouver le premier fichier .exe dans le répertoire de sortie pour ensuite trouver le nom du dll
for /F "delims=" %%I in ('dir bin\Debug\%DOTNET_VERSION%\*.exe /b /a-d') do (
    set "EXE_NAME=%%~nI"
    goto build_docker
)
echo Génération du Dockerfile avec .NET SDK version: %DOTNET_VERSION%

:build_docker
REM Générer le Dockerfile pour le conteneur de développement
(
echo # install dotnet
echo FROM mcr.microsoft.com/dotnet/sdk:%DOTNET_SDK_VERSION% AS build
echo WORKDIR /app
echo # copie le cs proj pour pointer le dotnet
echo COPY ./%CSPROJ_NAME% ./
echo RUN dotnet restore ./%CSPROJ_NAME%
echo # copie tout les fichier du projet
echo COPY . .
echo RUN dotnet publish ./%CSPROJ_NAME% -c Release -o out
echo # Stage 2: création en mode developpement
echo FROM mcr.microsoft.com/dotnet/sdk:%DOTNET_SDK_VERSION% AS development
echo WORKDIR /app
echo COPY --from=build /app/out .
echo ENTRYPOINT ["dotnet", "watch", "--project", "%CSPROJ_NAME%"]
echo # Création si on fait en mode production
echo FROM mcr.microsoft.com/dotnet/aspnet:%DOTNET_SDK_VERSION% AS production
echo WORKDIR /app
echo COPY --from=build /app/out .
echo EXPOSE 80
echo RUN dotnet dev-certs https
echo ENTRYPOINT ["dotnet", "%EXE_NAME%.dll"]
) > Dockerfile


REM Générer le Dockerfile pour le conteneur de test
(
echo # syntax=docker/dockerfile:1
echo FROM mcr.microsoft.com/dotnet/sdk:%DOTNET_SDK_VERSION% AS build
echo WORKDIR /app
echo # Copie les dossiers de l'application et des tests
echo COPY %EXE_NAME%/ ./%EXE_NAME%/
echo COPY test/ ./test/
echo # Construit l'application
echo RUN dotnet restore %EXE_NAME%/%EXE_NAME%.csproj
echo RUN dotnet build %EXE_NAME%/%EXE_NAME%.csproj -c Release
echo # Construit les test
echo RUN dotnet restore test/test.csproj
echo RUN dotnet build test/test.csproj -c Release
echo # Defini le repertoire des test
echo WORKDIR /app/test
echo # Définir la commande pour exécuter les tests et enregistrer les résultats
echo CMD ["dotnet", "test", "test.csproj", "--logger", "trx;LogFileName=test_results.trx", "--results-directory", "/app/test_results"]
) > ../Dockerfile.test

REM Générer le luch.sh
(
echo dotnet dev-certs https
echo echo ""
echo echo "Installtion de sudo"
echo apt-get update
echo apt-get install sudo
echo echo ""
echo echo ""
echo echo "Installer les dépendances nécessaires à xdg"
echo sudo apt-get update
echo sudo apt-get install xdg-utils
echo echo ""
echo xdg-open 'https://localhost:7218'
echo dotnet run
) > ./lunch.sh
REM Démarrer les services
docker-compose -p %PROJECT_NAME% up -d

set CONTAINER_NAME=%PROJECT_NAME%-dev-1
REM générer le code hexadécimal du conteneur
docker run --rm geircode/string_to_hex bash string_to_hex.bash "%CONTAINER_NAME%" > vscode_remote_hex.txt

REM Mettre le code exa dans une variable
set /p VSCODE_REMOTE_HEX=<vscode_remote_hex.txt

REM Ouvrir VS Code avec l'URI du conteneur
for /f "delims=" %%i in ('docker inspect -f "{{.NetworkSettings.Networks.%PROJECT_NAME%_default.IPAddress}}" %PROJECT_NAME%-db-1') do set DB_IP=%%i

echo IP de la DB: %DB_IP%

start http://localhost:5025/

code --folder-uri=vscode-remote://attached-container+%VSCODE_REMOTE_HEX%/app

REM Nettoyer le fichier temporaire
del vscode_remote_hex.txt

pause

endlocal
