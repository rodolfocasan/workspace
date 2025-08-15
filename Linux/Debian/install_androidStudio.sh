#!/bin/bash

################################################################################
#                    INSTALADOR DE ANDROID STUDIO PARA LINUX/DEBIAN           #
################################################################################
# Descripción: Script inteligente de automatización para instalar Android Studio,
#              JDK, Android SDK, herramientas de línea de comandos y dependencias
# Autor: Rodolfo Casan
# Versión: 1.0.0
# Ruta original del script: Linux/Debian/install_androidStudio.sh
#
# Este script configura un entorno completo de desarrollo Android usando Android Studio,
# incluyendo JDK, Android SDK, herramientas ADB, emulador y todas las dependencias
# necesarias. Incluye detección inteligente de instalaciones previas y descarga
# automática de la última versión estable.
################################################################################
set -e  # Salir si cualquier comando falla





################################################################################
#                              CONFIGURACIÓN GLOBAL                           #
################################################################################

# Variables de colores para mensajes
readonly ROJO='\033[0;31m'
readonly VERDE='\033[0;32m'
readonly AMARILLO='\033[1;33m'
readonly AZUL='\033[0;34m'
readonly MORADO='\033[0;35m'
readonly CIAN='\033[0;36m'
readonly NC='\033[0m' # Sin color

# Variables de configuración
readonly ANDROID_STUDIO_DIR="/opt/android-studio"
readonly ANDROID_SDK_DIR="$HOME/Android/Sdk"
readonly BASHRC_FILE="$HOME/.bashrc"
readonly SCRIPT_VERSION="1.0.0"
readonly TEMP_DIR="/tmp/android_studio_installer"

# URL para Command Line Tools
readonly CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"





################################################################################
#                            FUNCIONES DE UTILIDADES                          #
################################################################################

# Función para mostrar banner del script
mostrar_banner() {
    echo -e "${CIAN}"
    echo "=============================================================================="
    echo "                    INSTALADOR DE ANDROID STUDIO v${SCRIPT_VERSION}"
    echo "=============================================================================="
    echo -e "${NC}"
    echo -e "${MORADO}Desarrollado por Rodolfo Casan"
    echo ""
    echo "Este script configurará:"
    echo "• Android Studio (última versión estable)"
    echo "• Oracle JDK 21 (requerido para Android Studio)"
    echo "• Android SDK y herramientas de línea de comandos"
    echo "• Android SDK Build Tools y Platform Tools (ADB)"
    echo "• Android Emulator y dependencias del sistema"
    echo "• Variables de entorno y configuración PATH"
    echo ""
}

# Función para mostrar mensajes con formato
mostrar_mensaje() {
    echo -e "${AZUL}[INFO]${NC} $1"
}

mostrar_exito() {
    echo -e "${VERDE}[ÉXITO]${NC} $1"
}

mostrar_advertencia() {
    echo -e "${AMARILLO}[ADVERTENCIA]${NC} $1"
}

mostrar_error() {
    echo -e "${ROJO}[ERROR]${NC} $1"
}

mostrar_seccion() {
    echo ""
    echo -e "${CIAN}========================= $1 =========================${NC}"
    echo ""
}

# Función para pausar y solicitar confirmación
solicitar_confirmacion() {
    echo -e "${AMARILLO}¿Deseas continuar con la instalación? (s/N):${NC}"
    read -r respuesta
    case "$respuesta" in
        [sS]|[sS][iI]) return 0 ;;
        *) 
            mostrar_mensaje "Instalación cancelada por el usuario"
            exit 0 
            ;;
    esac
}

# Función para crear directorio temporal
crear_directorio_temporal() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    mkdir -p "$TEMP_DIR"
    mostrar_mensaje "Directorio temporal creado: $TEMP_DIR"
}

# Función para limpiar archivos temporales
limpiar_temporales() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        mostrar_mensaje "Archivos temporales limpiados"
    fi
}





################################################################################
#                          FUNCIONES DE VERIFICACIÓN                          #
################################################################################

# Verificar si el script se ejecuta como root
verificar_root() {
    if [[ $EUID -eq 0 ]]; then
        mostrar_error "Este script no debe ejecutarse como root"
        mostrar_mensaje "Ejecuta el script como usuario normal: ./install_androidStudio.sh"
        exit 1
    fi
}

# Verificar si estamos en sistema compatible
verificar_sistema() {
    if ! command -v apt >/dev/null 2>&1; then
        mostrar_error "Este script está diseñado para sistemas basados en Debian/Ubuntu"
        mostrar_mensaje "Sistemas compatibles: Debian, Ubuntu, Linux Mint, etc."
        exit 1
    fi
    
    # Verificar arquitectura de 64 bits
    if [ "$(uname -m)" != "x86_64" ]; then
        mostrar_error "Android Studio requiere un sistema de 64 bits"
        mostrar_mensaje "Arquitectura detectada: $(uname -m)"
        exit 1
    fi
    
    local os_info
    os_info=$(lsb_release -d 2>/dev/null | cut -f2- || echo "Sistema Debian/Ubuntu")
    mostrar_exito "Sistema compatible detectado: $os_info (64-bit)"
}

# Verificar conexión a internet
verificar_conexion() {
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        mostrar_error "No hay conexión a internet"
        mostrar_mensaje "Se requiere conexión a internet para descargar Android Studio y dependencias"
        exit 1
    fi
    mostrar_exito "Conexión a internet verificada"
}

# Verificar requisitos de hardware
verificar_hardware() {
    mostrar_mensaje "Verificando requisitos de hardware..."
    
    # Verificar RAM
    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$ram_gb" -lt 8 ]; then
        mostrar_advertencia "RAM detectada: ${ram_gb}GB (mínimo recomendado: 8GB)"
        mostrar_mensaje "El rendimiento podría verse afectado"
    else
        mostrar_exito "RAM verificada: ${ram_gb}GB (suficiente)"
    fi
    
    # Verificar espacio en disco
    local disk_gb
    disk_gb=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
    if [ "$disk_gb" -lt 16 ]; then
        mostrar_error "Espacio en disco insuficiente: ${disk_gb}GB disponible"
        mostrar_mensaje "Se requieren al menos 16GB de espacio libre"
        exit 1
    else
        mostrar_exito "Espacio en disco verificado: ${disk_gb}GB disponible"
    fi
    
    # Verificar soporte de virtualización
    if grep -q -E 'vmx|svm' /proc/cpuinfo; then
        mostrar_exito "Soporte de virtualización detectado (requerido para emulador)"
    else
        mostrar_advertencia "No se detectó soporte de virtualización"
        mostrar_mensaje "El emulador Android podría no funcionar correctamente"
    fi
}

# Detectar instalaciones previas de Android Studio
detectar_android_studio_existente() {
    local android_studio_detectado=false
    local version_actual=""
    local ubicacion_studio=""
    local sdk_detectado=false
    local ubicacion_sdk=""
    
    mostrar_mensaje "Detectando instalaciones previas de Android Studio..."
    
    # Verificar ubicaciones comunes de Android Studio
    local ubicaciones_studio=(
        "/opt/android-studio"
        "$HOME/android-studio"
        "/usr/local/android-studio"
        "$HOME/.local/share/android-studio"
    )
    
    for ubicacion in "${ubicaciones_studio[@]}"; do
        if [ -d "$ubicacion" ] && [ -f "$ubicacion/bin/studio.sh" ]; then
            android_studio_detectado=true
            ubicacion_studio="$ubicacion"
            
            # Intentar obtener versión
            if [ -f "$ubicacion/build.txt" ]; then
                version_actual=$(cat "$ubicacion/build.txt" | head -1 || echo "Versión desconocida")
            fi
            break
        fi
    done
    
    # Verificar Android SDK
    local ubicaciones_sdk=(
        "$HOME/Android/Sdk"
        "$ANDROID_SDK_DIR"
        "/opt/android-sdk"
        "$HOME/android-sdk"
    )
    
    for ubicacion in "${ubicaciones_sdk[@]}"; do
        if [ -d "$ubicacion" ] && [ -d "$ubicacion/platform-tools" ]; then
            sdk_detectado=true
            ubicacion_sdk="$ubicacion"
            break
        fi
    done
    
    # Verificar comando adb en PATH
    local adb_disponible=false
    if command -v adb >/dev/null 2>&1; then
        adb_disponible=true
    fi
    
    # Verificar configuración en archivos shell
    local configuracion_encontrada=false
    local archivos_config=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    for archivo in "${archivos_config[@]}"; do
        if [ -f "$archivo" ] && grep -q "ANDROID_HOME\|ANDROID_SDK_ROOT" "$archivo" 2>/dev/null; then
            configuracion_encontrada=true
            break
        fi
    done
    
    # Mostrar resultados de la detección
    if [ "$android_studio_detectado" = true ] || [ "$sdk_detectado" = true ]; then
        echo ""
        mostrar_advertencia "¡INSTALACIÓN DE ANDROID EXISTENTE DETECTADA!"
        echo ""
        echo -e "${AMARILLO}=== INFORMACIÓN DE LA INSTALACIÓN ACTUAL ===${NC}"
        
        if [ "$android_studio_detectado" = true ]; then
            echo -e "${CIAN}Android Studio:${NC} ✓ Detectado"
            echo -e "${CIAN}Ubicación:${NC} $ubicacion_studio"
            if [ -n "$version_actual" ]; then
                echo -e "${CIAN}Versión:${NC} $version_actual"
            fi
        else
            echo -e "${CIAN}Android Studio:${NC} ✗ No detectado"
        fi
        
        if [ "$sdk_detectado" = true ]; then
            echo -e "${CIAN}Android SDK:${NC} ✓ Detectado"
            echo -e "${CIAN}Ubicación SDK:${NC} $ubicacion_sdk"
        else
            echo -e "${CIAN}Android SDK:${NC} ✗ No detectado"
        fi
        
        if [ "$adb_disponible" = true ]; then
            local adb_version
            adb_version=$(adb version 2>/dev/null | head -1 || echo "Versión desconocida")
            echo -e "${CIAN}ADB en PATH:${NC} ✓ Disponible ($adb_version)"
        else
            echo -e "${CIAN}ADB en PATH:${NC} ✗ No disponible"
        fi
        
        if [ "$configuracion_encontrada" = true ]; then
            echo -e "${CIAN}Configuración shell:${NC} ✓ Detectada"
        else
            echo -e "${CIAN}Configuración shell:${NC} ✗ No detectada"
        fi
        
        echo ""
        return 0
    else
        mostrar_exito "No se detectó ninguna instalación previa de Android Studio"
        return 1
    fi
}

# Función para manejar reinstalación
manejar_reinstalacion() {
    echo -e "${AMARILLO}=== OPCIONES DE REINSTALACIÓN ===${NC}"
    echo ""
    echo "Tienes las siguientes opciones:"
    echo ""
    echo -e "${VERDE}1)${NC} Mantener instalación actual y salir"
    echo -e "${VERDE}2)${NC} Actualizar/Reparar instalación existente"
    echo -e "${VERDE}3)${NC} REINSTALACIÓN COMPLETA (eliminar todo y reinstalar)"
    echo -e "${VERDE}4)${NC} Cancelar y salir"
    echo ""
    
    while true; do
        echo -e "${CIAN}Selecciona una opción [1-4]:${NC} "
        read -r opcion
        
        case "$opcion" in
            1)
                mostrar_mensaje "Manteniendo instalación existente"
                verificar_configuracion_actual
                mostrar_guia_uso
                exit 0
                ;;
            2)
                mostrar_mensaje "Procediendo con actualización/reparación..."
                return 0
                ;;
            3)
                mostrar_advertencia "¡ATENCIÓN! Esto eliminará COMPLETAMENTE Android Studio y el SDK"
                echo -e "${ROJO}Se perderán:${NC}"
                echo "  • Android Studio instalado"
                echo "  • Android SDK y todas las plataformas descargadas"
                echo "  • AVDs (Android Virtual Devices) creados"
                echo "  • Configuraciones personalizadas"
                echo ""
                echo -e "${AMARILLO}¿Estás SEGURO de que deseas continuar? (escribe 'CONFIRMAR' para proceder):${NC}"
                read -r confirmacion
                
                if [ "$confirmacion" = "CONFIRMAR" ]; then
                    eliminar_android_completo
                    return 0
                else
                    mostrar_mensaje "Reinstalación cancelada"
                    exit 0
                fi
                ;;
            4)
                mostrar_mensaje "Operación cancelada por el usuario"
                exit 0
                ;;
            *)
                mostrar_error "Opción inválida. Por favor selecciona 1, 2, 3 o 4"
                ;;
        esac
    done
}

# Verificar configuración actual
verificar_configuracion_actual() {
    mostrar_seccion "VERIFICANDO CONFIGURACIÓN ACTUAL"
    
    if command -v studio.sh >/dev/null 2>&1; then
        mostrar_exito "Android Studio disponible en PATH"
    else
        mostrar_advertencia "Android Studio no disponible en PATH"
    fi
    
    if command -v adb >/dev/null 2>&1; then
        local adb_version
        adb_version=$(adb version 2>/dev/null | head -1)
        mostrar_exito "ADB funcionando: $adb_version"
    else
        mostrar_advertencia "ADB no disponible en PATH"
    fi
    
    if [ -n "$ANDROID_HOME" ]; then
        mostrar_exito "Variable ANDROID_HOME configurada: $ANDROID_HOME"
    else
        mostrar_advertencia "Variable ANDROID_HOME no configurada"
    fi
}

# Eliminar Android Studio completamente
eliminar_android_completo() {
    mostrar_seccion "ELIMINANDO INSTALACIÓN COMPLETA"
    
    # Eliminar directorios de Android Studio
    local directorios_eliminar=(
        "/opt/android-studio"
        "$HOME/android-studio"
        "/usr/local/android-studio"
        "$HOME/.local/share/android-studio"
        "$HOME/Android"
        "$HOME/.android"
        "$HOME/.AndroidStudio*"
    )
    
    for directorio in "${directorios_eliminar[@]}"; do
        if [ -d "$directorio" ]; then
            mostrar_mensaje "Eliminando: $directorio"
            sudo rm -rf "$directorio" 2>/dev/null || rm -rf "$directorio"
        fi
    done
    
    # Limpiar configuración de archivos shell
    mostrar_mensaje "Limpiando configuración de archivos shell..."
    
    local archivos_limpiar=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    for archivo in "${archivos_limpiar[@]}"; do
        if [ -f "$archivo" ]; then
            cp "$archivo" "${archivo}.backup_pre_reinstall_android_$(date +%Y%m%d_%H%M%S)"
            sed -i '/# Configuración de Android/,/################################################################################/d' "$archivo" 2>/dev/null || true
            sed -i '/ANDROID_HOME/d; /ANDROID_SDK_ROOT/d' "$archivo" 2>/dev/null || true
            mostrar_mensaje "Limpiado: $archivo"
        fi
    done
    
    mostrar_exito "Android Studio eliminado completamente del sistema"
}





################################################################################
#                        FUNCIONES DE INSTALACIÓN                             #
################################################################################

# Actualizar repositorios del sistema
actualizar_repositorios() {
    mostrar_seccion "ACTUALIZANDO REPOSITORIOS"
    
    mostrar_mensaje "Actualizando listas de paquetes..."
    if sudo apt update; then
        mostrar_exito "Repositorios actualizados correctamente"
    else
        mostrar_error "Falló la actualización de repositorios"
        exit 1
    fi
}

# Instalar JDK (requerido para Android Studio)
instalar_jdk() {
    mostrar_seccion "INSTALANDO ORACLE JDK"
    
    if java -version 2>&1 | grep -q "openjdk\|java"; then
        local java_version
        java_version=$(java -version 2>&1 | head -1)
        mostrar_mensaje "Java detectado: $java_version"
        
        # Verificar si es una versión compatible (11, 17, o 21)
        if java -version 2>&1 | grep -q -E "(11\.|17\.|21\.)"; then
            mostrar_exito "Versión de Java compatible detectada"
            return 0
        else
            mostrar_advertencia "Versión de Java no óptima para Android Studio"
        fi
    fi
    
    mostrar_mensaje "Instalando Oracle JDK 21 (recomendado para Android Studio)..."
    
    # Instalar OpenJDK 21 como alternativa libre
    if sudo apt install -y openjdk-21-jdk openjdk-21-jre; then
        mostrar_exito "JDK 21 instalado correctamente"
        
        # Configurar como default si hay múltiples versiones
        sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-21-openjdk-amd64/bin/java 1
        sudo update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-21-openjdk-amd64/bin/javac 1
        
        # Verificar instalación
        local nueva_version
        nueva_version=$(java -version 2>&1 | head -1)
        mostrar_exito "JDK configurado: $nueva_version"
    else
        mostrar_error "Falló la instalación de JDK"
        exit 1
    fi
}

# Instalar dependencias del sistema
instalar_dependencias() {
    mostrar_seccion "INSTALANDO DEPENDENCIAS DEL SISTEMA"
    
    mostrar_mensaje "Instalando librerías de 32 bits y dependencias necesarias..."
    
    local dependencias=(
        # Librerías de 32 bits requeridas
        "libc6:i386"
        "libncurses5:i386"
        "libstdc++6:i386"
        "lib32z1"
        "libbz2-1.0:i386"
        
        # Herramientas básicas
        "curl"
        "wget"
        "unzip"
        "git"
        
        # Dependencias para emulador
        "qemu-kvm"
        "libvirt-daemon-system"
        "libvirt-clients"
        "bridge-utils"
        "cpu-checker"
        
        # Dependencias adicionales
        "mesa-utils"
        "libgl1-mesa-glx:i386"
        "libgl1-mesa-dev"
    )
    
    # Habilitar arquitectura i386 para paquetes de 32 bits
    if ! dpkg --print-foreign-architectures | grep -q i386; then
        mostrar_mensaje "Habilitando arquitectura i386 para librerías de 32 bits..."
        sudo dpkg --add-architecture i386
        sudo apt update
    fi
    
    mostrar_mensaje "Instalando ${#dependencias[@]} paquetes de dependencias..."
    
    if sudo apt install -y "${dependencias[@]}"; then
        mostrar_exito "Todas las dependencias fueron instaladas correctamente"
    else
        mostrar_advertencia "Algunas dependencias podrían no haberse instalado completamente"
        mostrar_mensaje "Continuando con la instalación..."
    fi
    
    # Configurar permisos para KVM (emulador)
    if [ -c "/dev/kvm" ]; then
        sudo usermod -aG kvm "$USER" 2>/dev/null || true
        mostrar_exito "Usuario agregado al grupo KVM para emulador"
    fi
}

# Obtener información de descarga de Android Studio
obtener_info_descarga() {
    # NO usar mostrar_mensaje aquí porque interfiere con la captura de output
    
    # URLs de Android Studio en orden de preferencia
    # Versión 2025.1.2.11 (Narwhal Feature Drop) - Más reciente
    local version1="2025.1.2.11"
    local archivo1="android-studio-${version1}-linux.tar.gz"
    local url1="https://dl.google.com/dl/android/studio/ide-zips/${version1}/${archivo1}"
    
    # Verificar primera opción (2025.1.2.11)
    if curl --output /dev/null --silent --head --fail --max-time 15 "$url1" 2>/dev/null; then
        echo "$archivo1|$url1"
        return 0
    fi
    
    # Versión 2024.2.1.12 (Koala) - Estable conocida
    local version2="2024.2.1.12"  
    local archivo2="android-studio-${version2}-linux.tar.gz"
    local url2="https://dl.google.com/dl/android/studio/ide-zips/${version2}/${archivo2}"
    
    if curl --output /dev/null --silent --head --fail --max-time 15 "$url2" 2>/dev/null; then
        echo "$archivo2|$url2"
        return 0
    fi
    
    # Versión 2024.1.2.12 - Otra alternativa
    local version3="2024.1.2.12"
    local archivo3="android-studio-${version3}-linux.tar.gz" 
    local url3="https://dl.google.com/dl/android/studio/ide-zips/${version3}/${archivo3}"
    
    if curl --output /dev/null --silent --head --fail --max-time 15 "$url3" 2>/dev/null; then
        echo "$archivo3|$url3"
        return 0
    fi
    
    # Fallback final - versión 2023.3.1.19 (conocida que funciona)
    local archivo_fallback="android-studio-2023.3.1.19-linux.tar.gz"
    local url_fallback="https://dl.google.com/dl/android/studio/ide-zips/2023.3.1.19/${archivo_fallback}"
    echo "$archivo_fallback|$url_fallback"
}

# Descargar e instalar Android Studio
instalar_android_studio() {
    mostrar_seccion "DESCARGANDO E INSTALANDO ANDROID STUDIO"
    
    crear_directorio_temporal
    cd "$TEMP_DIR"
    
    mostrar_mensaje "Preparando descarga de Android Studio..."
    
    # Obtener información de descarga
    local info_descarga
    info_descarga=$(obtener_info_descarga)
    
    # Verificar que obtuvimos una respuesta válida
    if [[ ! "$info_descarga" =~ .+\|.+ ]]; then
        mostrar_error "No se pudo obtener información de descarga válida"
        mostrar_mensaje "Respuesta recibida: $info_descarga"
        limpiar_temporales
        exit 1
    fi
    
    local archivo_descarga
    archivo_descarga=$(echo "$info_descarga" | cut -d'|' -f1)
    local url_descarga
    url_descarga=$(echo "$info_descarga" | cut -d'|' -f2)
    
    mostrar_mensaje "Descargando Android Studio..."
    mostrar_mensaje "Archivo: $archivo_descarga"
    mostrar_mensaje "Desde: $(echo "$url_descarga" | cut -d'/' -f3)"
    
    # Descargar con reintentos y mejor manejo de errores
    local intentos=0
    local max_intentos=3
    
    while [ $intentos -lt $max_intentos ]; do
        intentos=$((intentos + 1))
        mostrar_mensaje "Intento $intentos de $max_intentos..."
        
        # Usar curl en lugar de wget para mejor control de errores
        if curl -L --progress-bar --fail --connect-timeout 30 --max-time 1800 -o "$archivo_descarga" "$url_descarga"; then
            mostrar_exito "Android Studio descargado correctamente"
            break
        else
            if [ $intentos -lt $max_intentos ]; then
                mostrar_advertencia "Intento $intentos falló, reintentando en 5 segundos..."
                sleep 5
            else
                mostrar_error "Falló la descarga de Android Studio después de $max_intentos intentos"
                mostrar_mensaje "URL intentada: $url_descarga"
                
                # Intentar URL alternativa como último recurso
                mostrar_mensaje "Intentando con URL alternativa..."
                local url_alternativa="https://dl.google.com/android/studio/ide-zips/2024.2.1.12/android-studio-2024.2.1.12-linux.tar.gz"
                local archivo_alternativo="android-studio-2024.2.1.12-linux.tar.gz"
                
                if curl -L --progress-bar --fail --connect-timeout 30 --max-time 1800 -o "$archivo_alternativo" "$url_alternativa"; then
                    archivo_descarga="$archivo_alternativo"
                    mostrar_exito "Android Studio descargado con URL alternativa"
                    break
                else
                    mostrar_error "Todas las opciones de descarga fallaron"
                    mostrar_mensaje "Verifica tu conexión a internet y vuelve a intentar"
                    limpiar_temporales
                    exit 1
                fi
            fi
        fi
    done
    
    # Verificar integridad del archivo descargado
    if [ ! -f "$archivo_descarga" ] || [ ! -s "$archivo_descarga" ]; then
        mostrar_error "El archivo descargado está corrupto o vacío"
        limpiar_temporales
        exit 1
    fi
    
    # Verificar que es un archivo tar.gz válido
    mostrar_mensaje "Verificando integridad del archivo descargado..."
    if ! file "$archivo_descarga" | grep -q "gzip compressed"; then
        mostrar_error "El archivo descargado no es un tar.gz válido"
        mostrar_mensaje "Tipo de archivo detectado: $(file "$archivo_descarga")"
        limpiar_temporales
        exit 1
    fi
    
    # Extraer Android Studio
    mostrar_mensaje "Extrayendo Android Studio..."
    if tar -xzf "$archivo_descarga"; then
        mostrar_exito "Android Studio extraído correctamente"
    else
        mostrar_error "Falló la extracción de Android Studio"
        limpiar_temporales
        exit 1
    fi
    
    # Mover a directorio de instalación
    mostrar_mensaje "Instalando Android Studio en $ANDROID_STUDIO_DIR..."
    if [ -d "android-studio" ]; then
        sudo rm -rf "$ANDROID_STUDIO_DIR" 2>/dev/null || true
        sudo mv "android-studio" "$ANDROID_STUDIO_DIR"
        sudo chown -R "$USER:$USER" "$ANDROID_STUDIO_DIR" 2>/dev/null || true
        mostrar_exito "Android Studio instalado en $ANDROID_STUDIO_DIR"
    else
        mostrar_error "No se encontró el directorio extraído de Android Studio"
        mostrar_mensaje "Contenido del directorio temporal:"
        ls -la
        limpiar_temporales
        exit 1
    fi
    
    # Crear enlace simbólico para facilitar ejecución
    sudo ln -sf "$ANDROID_STUDIO_DIR/bin/studio.sh" "/usr/local/bin/studio" 2>/dev/null || true
    
    cd - >/dev/null
    limpiar_temporales
}

# Instalar Android SDK Command Line Tools
instalar_sdk_tools() {
    mostrar_seccion "INSTALANDO ANDROID SDK COMMAND LINE TOOLS"
    
    crear_directorio_temporal
    cd "$TEMP_DIR"
    
    # Crear directorio SDK
    mkdir -p "$ANDROID_SDK_DIR"
    
    mostrar_mensaje "Descargando Android SDK Command Line Tools..."
    if wget -O "commandlinetools.zip" "$CMDLINE_TOOLS_URL"; then
        mostrar_exito "Command Line Tools descargado correctamente"
    else
        mostrar_error "Falló la descarga de Command Line Tools"
        limpiar_temporales
        exit 1
    fi
    
    # Extraer herramientas
    mostrar_mensaje "Extrayendo Command Line Tools..."
    unzip -q "commandlinetools.zip"
    
    # Mover a la estructura correcta del SDK
    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
    mv cmdline-tools "$ANDROID_SDK_DIR/cmdline-tools/latest"
    
    mostrar_exito "Android SDK Command Line Tools instalado"
    
    cd - >/dev/null
    limpiar_temporales
}





################################################################################
#                         FUNCIONES DE CONFIGURACIÓN                          #
################################################################################

# Configurar variables de entorno
configurar_entorno() {
    mostrar_seccion "CONFIGURANDO ENTORNO"
    
    # Crear backup del .bashrc
    if [ -f "$BASHRC_FILE" ]; then
        local backup_file="${BASHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$BASHRC_FILE" "$backup_file"
        mostrar_mensaje "Backup creado: $backup_file"
    fi
    
    # Verificar si la configuración ya existe
    if grep -q "ANDROID_HOME" "$BASHRC_FILE" 2>/dev/null; then
        mostrar_advertencia "Configuración de Android ya presente en $BASHRC_FILE"
        mostrar_mensaje "Saltando configuración de variables de entorno"
    else
        mostrar_mensaje "Agregando configuración de Android a $BASHRC_FILE..."
        
        # Agregar configuración completa de Android
        cat >> "$BASHRC_FILE" << EOF

################################################################################
# Configuración de Android Studio & SDK - [Rodolfo Casan; Workspace Android]
# Agregado automáticamente por el instalador de Android Studio
################################################################################

# Definir directorios de Android
export ANDROID_HOME="$ANDROID_SDK_DIR"
export ANDROID_SDK_ROOT="\$ANDROID_HOME"

# Agregar herramientas de Android al PATH
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH"
export PATH="\$ANDROID_HOME/platform-tools:\$PATH"
export PATH="\$ANDROID_HOME/emulator:\$PATH"
export PATH="\$ANDROID_HOME/tools:\$PATH"
export PATH="$ANDROID_STUDIO_DIR/bin:\$PATH"

# Configuración adicional para emulador
export ANDROID_EMULATOR_USE_SYSTEM_LIBS=1

################################################################################
EOF
        
        mostrar_exito "Configuración de entorno agregada correctamente"
    fi
}

# Aplicar configuración en la sesión actual
aplicar_configuracion() {
    mostrar_seccion "APLICANDO CONFIGURACIÓN"
    
    mostrar_mensaje "Configurando variables de entorno para la sesión actual..."
    
    # Exportar variables para la sesión actual
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
    export PATH="$ANDROID_HOME/platform-tools:$PATH"
    export PATH="$ANDROID_HOME/emulator:$PATH"
    export PATH="$ANDROID_STUDIO_DIR/bin:$PATH"
    
    mostrar_exito "Variables de entorno configuradas para la sesión actual"
}

# Instalar componentes básicos del SDK
instalar_componentes_sdk() {
    mostrar_seccion "INSTALANDO COMPONENTES BÁSICOS DEL SDK"
    
    if [ ! -f "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
        mostrar_advertencia "SDK Manager no encontrado, saltando instalación de componentes"
        return
    fi
    
    mostrar_mensaje "Aceptando licencias del SDK..."
    yes | "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
    
    mostrar_mensaje "Instalando componentes básicos del SDK..."
    
    local componentes=(
        "platform-tools"
        "build-tools;35.0.0"
        "platforms;android-35"
        "emulator"
        "system-images;android-35;google_apis;x86_64"
    )
    
    for componente in "${componentes[@]}"; do
        mostrar_mensaje "Instalando: $componente"
        "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" "$componente" >/dev/null 2>&1 || {
            mostrar_advertencia "No se pudo instalar: $componente"
        }
    done
    
    mostrar_exito "Componentes básicos del SDK instalados"
}





################################################################################
#                          FUNCIONES DE VERIFICACIÓN POST-INSTALACIÓN         #
################################################################################

# Verificar que la instalación fue exitosa
verificar_instalacion_exitosa() {
    mostrar_seccion "VERIFICANDO INSTALACIÓN"
    
    # Recargar configuración
    source "$BASHRC_FILE" 2>/dev/null || true
    
    # Verificar Android Studio
    if [ -f "$ANDROID_STUDIO_DIR/bin/studio.sh" ]; then
        mostrar_exito "Android Studio instalado correctamente"
        
        # Obtener versión si está disponible
        if [ -f "$ANDROID_STUDIO_DIR/build.txt" ]; then
            local version
            version=$(cat "$ANDROID_STUDIO_DIR/build.txt" | head -1 2>/dev/null || echo "Versión no disponible")
            mostrar_mensaje "Versión instalada: $version"
        fi
    else
        mostrar_error "Android Studio no se instaló correctamente"
    fi
    
    # Verificar ADB
    export PATH="$ANDROID_SDK_DIR/platform-tools:$PATH"
    if [ -f "$ANDROID_SDK_DIR/platform-tools/adb" ]; then
        mostrar_exito "ADB instalado correctamente"
        local adb_version
        adb_version=$("$ANDROID_SDK_DIR/platform-tools/adb" version 2>/dev/null | head -1 || echo "Versión no disponible")
        mostrar_mensaje "ADB: $adb_version"
    else
        mostrar_advertencia "ADB no encontrado en platform-tools"
    fi
    
    # Verificar SDK Manager
    if [ -f "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
        mostrar_exito "SDK Manager disponible"
    else
        mostrar_advertencia "SDK Manager no encontrado"
    fi
    
    # Verificar variables de entorno
    if [ -n "$ANDROID_HOME" ]; then
        mostrar_exito "Variable ANDROID_HOME configurada: $ANDROID_HOME"
    else
        mostrar_advertencia "Variable ANDROID_HOME no configurada"
    fi
}

# Mostrar guía de uso
mostrar_guia_uso() {
    mostrar_seccion "GUÍA DE USO DE ANDROID STUDIO"
    
    echo -e "${VERDE}Comandos básicos:${NC}"
    echo ""
    echo -e "${CIAN}Ejecutar Android Studio:${NC}"
    echo "  studio"
    echo "  # o directamente: $ANDROID_STUDIO_DIR/bin/studio.sh"
    echo ""
    echo -e "${CIAN}Gestionar SDK (después de reiniciar terminal):${NC}"
    echo "  sdkmanager --list                    # Listar paquetes disponibles"
    echo "  sdkmanager 'platforms;android-34'   # Instalar plataforma específica"
    echo "  sdkmanager 'build-tools;34.0.0'     # Instalar build tools"
    echo ""
    echo -e "${CIAN}Herramientas ADB:${NC}"
    echo "  adb devices                          # Listar dispositivos conectados"
    echo "  adb install app.apk                  # Instalar aplicación"
    echo "  adb logcat                           # Ver logs del dispositivo"
    echo ""
    echo -e "${CIAN}Crear AVD (Android Virtual Device):${NC}"
    echo "  avdmanager create avd -n Mi_AVD -k 'system-images;android-35;google_apis;x86_64'"
    echo ""
    echo -e "${CIAN}Ejecutar emulador:${NC}"
    echo "  emulator -avd Mi_AVD"
    echo ""
}

# Mostrar instrucciones finales
mostrar_instrucciones_finales() {
    mostrar_seccion "INSTALACIÓN COMPLETADA"
    
    echo -e "${VERDE}¡Instalación de Android Studio completada exitosamente!${NC}"
    echo ""
    echo -e "${AMARILLO}PASOS SIGUIENTES:${NC}"
    echo "1. ${CIAN}Reinicia tu terminal${NC} o ejecuta: ${MORADO}source ~/.bashrc${NC}"
    echo "2. ${CIAN}Ejecuta Android Studio${NC}: ${MORADO}studio${NC}"
    echo "3. ${CIAN}Configura el SDK${NC} siguiendo el Setup Wizard inicial"
    echo "4. ${CIAN}Crea tu primer AVD${NC} desde Android Studio > Tools > AVD Manager"
    echo ""
    echo -e "${AMARILLO}UBICACIONES IMPORTANTES:${NC}"
    echo "• Android Studio: ${MORADO}$ANDROID_STUDIO_DIR${NC}"
    echo "• Android SDK: ${MORADO}$ANDROID_SDK_DIR${NC}"
    echo "• ADB: ${MORADO}$ANDROID_SDK_DIR/platform-tools/adb${NC}"
    echo ""
    echo -e "${AMARILLO}WORKSPACE ANDROID CONFIGURADO:${NC}"
    echo "• Runtime Configuration (RC) aplicada correctamente"
    echo "• Entorno de desarrollo Android listo para usar"
    echo "• SDK y herramientas de línea de comandos instalados"
    echo "• Emulador y ADB configurados"
    echo ""
    echo -e "${MORADO}[RC; Workspace Android]${NC} - Configuración completada por Rodolfo Casan"
}





################################################################################
#                              FUNCIÓN PRINCIPAL                              #
################################################################################

main() {
    # Mostrar banner inicial
    mostrar_banner
    
    # Solicitar confirmación antes de proceder
    solicitar_confirmacion
    
    # Verificaciones previas
    mostrar_seccion "VERIFICACIONES PREVIAS"
    verificar_root
    verificar_sistema
    verificar_conexion
    verificar_hardware
    
    # Detección inteligente de Android Studio existente
    if detectar_android_studio_existente; then
        manejar_reinstalacion
    fi
    
    # Proceso de instalación
    actualizar_repositorios
    instalar_jdk
    instalar_dependencias
    instalar_android_studio
    instalar_sdk_tools
    
    # Configuración del entorno
    configurar_entorno
    aplicar_configuracion
    instalar_componentes_sdk
    
    # Verificación final
    verificar_instalacion_exitosa
    mostrar_guia_uso
    mostrar_instrucciones_finales
    
    echo ""
    mostrar_exito "Script completado exitosamente"
    mostrar_mensaje "¡Reinicia tu terminal para usar Android Studio!"
}

# Configurar trap para limpiar en caso de interrupción
trap 'limpiar_temporales; exit 1' INT TERM





# Ejecutar función principal con todos los argumentos
main "$@"