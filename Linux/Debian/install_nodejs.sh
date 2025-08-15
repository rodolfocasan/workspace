#!/bin/bash

################################################################################
#                    INSTALADOR DE NODE.JS PARA LINUX/DEBIAN                  #
################################################################################
# Descripción: Script inteligente de automatización para instalar Node.js y NVM
# Autor: Rodolfo Casan
# Versión: 1.0.0
# Ruta original del script: Linux/Debian/install_nodejs.sh
#
# Este script configura un entorno completo de desarrollo Node.js usando NVM,
# permitiendo gestionar múltiples versiones de Node.js de forma aislada y
# controlada en el workspace de desarrollo. Incluye detección inteligente de
# instalaciones previas y opciones de reinstalación completa.
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
readonly NVM_INSTALLER_URL="https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh"
readonly NVM_DIR="$HOME/.nvm"
readonly BASHRC_FILE="$HOME/.bashrc"
readonly PROFILE_FILE="$HOME/.profile"
readonly SCRIPT_VERSION="1.0.0"
readonly NODE_LTS_VERSION="lts"





################################################################################
#                            FUNCIONES DE UTILIDADES                          #
################################################################################

# Función para mostrar banner del script
mostrar_banner() {
    echo -e "${CIAN}"
    echo "=============================================================================="
    echo "                   INSTALADOR DE NODE.JS PARA DEBIAN v${SCRIPT_VERSION}"
    echo "=============================================================================="
    echo -e "${NC}"
    echo -e "${MORADO}Desarrollado por Rodolfo Casan"
    echo ""
    echo "Este script configurará:"
    echo "• NVM (Node Version Manager)"
    echo "• Node.js (última versión LTS)"
    echo "• NPM (Node Package Manager)"
    echo "• Variables de entorno"
    echo "• Workspace Node.js completo"
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





################################################################################
#                          FUNCIONES DE VERIFICACIÓN                          #
################################################################################

# Verificar si el script se ejecuta como root
verificar_root() {
    if [[ $EUID -eq 0 ]]; then
        mostrar_error "Este script no debe ejecutarse como root"
        mostrar_mensaje "Ejecuta el script como usuario normal: ./install_nodejs.sh"
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
    
    local os_info
    os_info=$(lsb_release -d 2>/dev/null | cut -f2- || echo "Sistema Debian/Ubuntu")
    mostrar_exito "Sistema compatible detectado: $os_info"
}

# Verificar conexión a internet
verificar_conexion() {
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        mostrar_error "No hay conexión a internet"
        mostrar_mensaje "Se requiere conexión a internet para descargar NVM y Node.js"
        exit 1
    fi
    mostrar_exito "Conexión a internet verificada"
}

# Detectar y manejar instalaciones previas de Node.js/NVM de forma inteligente
detectar_nodejs_existente() {
    local nvm_detectado=false
    local nodejs_detectado=false
    local version_nvm=""
    local version_nodejs=""
    local ubicacion_nvm=""
    local metodo_instalacion=""
    local versiones_nodejs=()
    
    mostrar_mensaje "Detectando instalaciones previas de Node.js y NVM..."
    
    # Verificar NVM
    if [ -d "$NVM_DIR" ]; then
        nvm_detectado=true
        ubicacion_nvm="$NVM_DIR"
        
        # Verificar si NVM está funcional
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            version_nvm=$(bash -c "source $NVM_DIR/nvm.sh && nvm --version" 2>/dev/null || echo "Versión desconocida")
            
            # Obtener versiones de Node.js instaladas con NVM
            mapfile -t versiones_nodejs < <(bash -c "source $NVM_DIR/nvm.sh && nvm list --no-colors" 2>/dev/null | grep -v "N/A" | sed 's/[^v0-9.]//g' | grep -v "^$" || true)
        fi
        metodo_instalacion="NVM"
    fi
    
    # Verificar Node.js del sistema (apt/snap/otros)
    if command -v node >/dev/null 2>&1; then
        nodejs_detectado=true
        version_nodejs=$(node --version 2>/dev/null || echo "Versión desconocida")
        
        # Determinar método de instalación si no es NVM
        if [ "$nvm_detectado" = false ]; then
            if dpkg -l | grep -q nodejs 2>/dev/null; then
                metodo_instalacion="APT (repositorios Debian)"
            elif snap list 2>/dev/null | grep -q node; then
                metodo_instalacion="Snap"
            else
                metodo_instalacion="Método desconocido"
            fi
        fi
    fi
    
    # Verificar NPM
    local npm_detectado=false
    local version_npm=""
    if command -v npm >/dev/null 2>&1; then
        npm_detectado=true
        version_npm=$(npm --version 2>/dev/null || echo "Versión desconocida")
    fi
    
    # Verificar configuración en archivos de shell
    local archivos_config=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    local configuracion_encontrada=false
    for archivo in "${archivos_config[@]}"; do
        if [ -f "$archivo" ] && grep -q "NVM_DIR\|nvm.sh" "$archivo" 2>/dev/null; then
            configuracion_encontrada=true
            break
        fi
    done
    
    # Mostrar resultados de la detección
    if [ "$nvm_detectado" = true ] || [ "$nodejs_detectado" = true ]; then
        echo ""
        mostrar_advertencia "¡NODE.JS/NVM YA ESTÁ INSTALADO EN EL SISTEMA!"
        echo ""
        echo -e "${AMARILLO}=== INFORMACIÓN DE LA INSTALACIÓN ACTUAL ===${NC}"
        
        if [ "$nvm_detectado" = true ]; then
            echo -e "${CIAN}NVM detectado:${NC} ✓"
            echo -e "${CIAN}Versión de NVM:${NC} $version_nvm"
            echo -e "${CIAN}Ubicación:${NC} $ubicacion_nvm"
        else
            echo -e "${CIAN}NVM detectado:${NC} ✗"
        fi
        
        if [ "$nodejs_detectado" = true ]; then
            echo -e "${CIAN}Node.js detectado:${NC} ✓ ($version_nodejs)"
            echo -e "${CIAN}Método de instalación:${NC} $metodo_instalacion"
        else
            echo -e "${CIAN}Node.js detectado:${NC} ✗"
        fi
        
        if [ "$npm_detectado" = true ]; then
            echo -e "${CIAN}NPM detectado:${NC} ✓ (v$version_npm)"
        else
            echo -e "${CIAN}NPM detectado:${NC} ✗"
        fi
        
        if [ "$configuracion_encontrada" = true ]; then
            echo -e "${CIAN}Configuración en shell:${NC} ✓ Detectada"
        else
            echo -e "${CIAN}Configuración en shell:${NC} ✗ No detectada o incompleta"
        fi
        
        if [ ${#versiones_nodejs[@]} -gt 0 ]; then
            echo -e "${CIAN}Versiones de Node.js (NVM) instaladas (${#versiones_nodejs[@]}):${NC}"
            for version in "${versiones_nodejs[@]}"; do
                if [ -n "$version" ]; then
                    echo "  • $version"
                fi
            done
        fi
        
        echo ""
        return 0
    else
        mostrar_exito "No se detectó ninguna instalación previa de Node.js/NVM"
        return 1
    fi
}

# Función mejorada para manejar reinstalación
manejar_reinstalacion() {
    echo -e "${AMARILLO}=== OPCIONES DE REINSTALACIÓN ===${NC}"
    echo ""
    echo "Tienes las siguientes opciones:"
    echo ""
    echo -e "${VERDE}1)${NC} Mantener instalación actual y salir"
    echo -e "${VERDE}2)${NC} Reparar/Actualizar instalación existente"
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
                mostrar_mensaje "Procediendo con reparación/actualización..."
                reparar_instalacion
                return 0
                ;;
            3)
                mostrar_advertencia "¡ATENCIÓN! Esto eliminará COMPLETAMENTE tu instalación actual"
                echo -e "${ROJO}Se perderán:${NC}"
                echo "  • Todas las versiones de Node.js instaladas con NVM"
                echo "  • Configuraciones personalizadas"
                echo "  • Paquetes globales de NPM instalados"
                echo ""
                echo -e "${AMARILLO}¿Estás SEGURO de que deseas continuar? (escribe 'CONFIRMAR' para proceder):${NC}"
                read -r confirmacion
                
                if [ "$confirmacion" = "CONFIRMAR" ]; then
                    eliminar_nodejs_completo
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

# Verificar y mostrar estado de la configuración actual
verificar_configuracion_actual() {
    mostrar_seccion "VERIFICANDO CONFIGURACIÓN ACTUAL"
    
    if command -v nvm >/dev/null 2>&1; then
        local version=$(nvm --version)
        mostrar_exito "NVM funcionando correctamente: v$version"
        
        # Verificar Node.js
        if command -v node >/dev/null 2>&1; then
            local node_version=$(node --version)
            mostrar_exito "Node.js disponible: $node_version"
        fi
        
        # Verificar NPM
        if command -v npm >/dev/null 2>&1; then
            local npm_version=$(npm --version)
            mostrar_exito "NPM disponible: v$npm_version"
        fi
        
    else
        mostrar_advertencia "NVM instalado pero no disponible en PATH"
        mostrar_mensaje "Es posible que necesites reiniciar tu terminal"
    fi
}

# Reparar instalación existente
reparar_instalacion() {
    mostrar_seccion "REPARANDO INSTALACIÓN DE NVM/NODE.JS"
    
    # Actualizar NVM si está instalado
    if [ -d "$NVM_DIR" ]; then
        mostrar_mensaje "Actualizando NVM a la última versión..."
        instalar_nvm
    fi
    
    # Verificar y reparar configuración
    mostrar_mensaje "Verificando configuración en archivos shell..."
    if ! grep -q "NVM_DIR.*$HOME/.nvm" "$BASHRC_FILE" 2>/dev/null; then
        mostrar_mensaje "Agregando configuración faltante..."
        configurar_entorno
    else
        mostrar_exito "Configuración está correcta"
    fi
    
    # Reinstalar dependencias básicas
    instalar_dependencias_basicas
    
    # Aplicar configuración
    aplicar_configuracion
    
    # Instalar Node.js LTS si no está instalado
    instalar_nodejs_lts
    
    verificar_instalacion_exitosa
    mostrar_exito "Reparación/actualización completada"
}

# Eliminar completamente Node.js/NVM
eliminar_nodejs_completo() {
    mostrar_seccion "ELIMINANDO INSTALACIÓN COMPLETA"
    
    mostrar_mensaje "Eliminando NVM y todas las versiones de Node.js..."
    
    # Eliminar directorio NVM
    if [ -d "$NVM_DIR" ]; then
        mostrar_mensaje "Eliminando: $NVM_DIR"
        rm -rf "$NVM_DIR"
    fi
    
    # Eliminar Node.js del sistema si está instalado via apt
    if dpkg -l | grep -q nodejs 2>/dev/null; then
        mostrar_mensaje "Eliminando Node.js del sistema (apt)..."
        sudo apt remove --purge -y nodejs npm 2>/dev/null || true
    fi
    
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
            # Crear backup antes de limpiar
            cp "$archivo" "${archivo}.backup_pre_nodejs_reinstall_$(date +%Y%m%d_%H%M%S)"
            
            # Eliminar líneas relacionadas con NVM
            sed -i '/# Configuración de NVM/,/################################################################################/d' "$archivo" 2>/dev/null || true
            sed -i '/NVM_DIR/d; /nvm.sh/d; /nvm init/d' "$archivo" 2>/dev/null || true
            
            mostrar_mensaje "Limpiado: $archivo"
        fi
    done
    
    mostrar_exito "Node.js y NVM eliminados completamente del sistema"
    mostrar_mensaje "Procediendo con instalación limpia..."
}





################################################################################
#                        FUNCIONES DE INSTALACIÓN                             #
################################################################################

# Instalar dependencias básicas
instalar_dependencias_basicas() {
    mostrar_seccion "INSTALANDO DEPENDENCIAS BÁSICAS"
    
    mostrar_mensaje "Actualizando repositorios..."
    sudo apt update >/dev/null 2>&1 || true
    
    local dependencias=(
        "curl"
        "wget"
        "build-essential"
        "git"
    )
    
    mostrar_mensaje "Instalando dependencias básicas..."
    
    if sudo apt install -y "${dependencias[@]}" >/dev/null 2>&1; then
        mostrar_exito "Dependencias básicas instaladas correctamente"
    else
        mostrar_advertencia "Algunas dependencias podrían no haberse instalado"
    fi
}

# Descargar e instalar NVM
instalar_nvm() {
    mostrar_seccion "INSTALANDO NVM (NODE VERSION MANAGER)"
    
    mostrar_mensaje "Descargando e instalando NVM desde GitHub..."
    mostrar_mensaje "URL: $NVM_INSTALLER_URL"
    
    if curl -o- "$NVM_INSTALLER_URL" | bash; then
        mostrar_exito "NVM instalado correctamente"
        
        # Verificar que el directorio se haya creado
        if [ -d "$NVM_DIR" ]; then
            mostrar_mensaje "Directorio NVM creado: $NVM_DIR"
        else
            mostrar_error "No se pudo crear el directorio NVM"
            exit 1
        fi
    else
        mostrar_error "Falló la instalación de NVM"
        exit 1
    fi
}

# Instalar Node.js LTS
instalar_nodejs_lts() {
    mostrar_mensaje "Instalando Node.js LTS..."
    
    # Cargar NVM en el shell actual
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if command -v nvm >/dev/null 2>&1; then
        if nvm install "$NODE_LTS_VERSION"; then
            mostrar_exito "Node.js LTS instalado correctamente"
            
            # Establecer como versión por defecto
            if nvm use "$NODE_LTS_VERSION" && nvm alias default "$NODE_LTS_VERSION"; then
                mostrar_exito "Node.js LTS establecido como versión por defecto"
            fi
        else
            mostrar_advertencia "No se pudo instalar Node.js LTS automáticamente"
            mostrar_mensaje "Podrás instalarlo manualmente después de reiniciar el terminal"
        fi
    else
        mostrar_advertencia "NVM no está disponible en esta sesión"
        mostrar_mensaje "Reinicia el terminal e instala Node.js con: nvm install $NODE_LTS_VERSION"
    fi
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
    if grep -q "NVM_DIR" "$BASHRC_FILE" 2>/dev/null; then
        mostrar_advertencia "Configuración de NVM ya presente en $BASHRC_FILE"
        mostrar_mensaje "Saltando configuración de variables de entorno"
    else
        mostrar_mensaje "Agregando configuración de NVM a $BASHRC_FILE..."
        
        # Agregar configuración completa de NVM
        cat >> "$BASHRC_FILE" << 'EOF'

################################################################################
# Configuración de NVM - [Rodolfo Casan; Workspace Node.js]
# Agregado automáticamente por el instalador de Node.js
################################################################################

# Definir directorio de NVM
export NVM_DIR="$HOME/.nvm"

# Cargar NVM y autocompletado si están disponibles
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

################################################################################
EOF
        
        mostrar_exito "Configuración de entorno agregada correctamente"
    fi
    
    # También agregar a .profile para compatibilidad
    if [ -f "$PROFILE_FILE" ] && ! grep -q "NVM_DIR" "$PROFILE_FILE" 2>/dev/null; then
        mostrar_mensaje "Agregando configuración básica a .profile..."
        cat >> "$PROFILE_FILE" << 'EOF'

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF
    fi
}

# Aplicar configuración en la sesión actual
aplicar_configuracion() {
    mostrar_seccion "APLICANDO CONFIGURACIÓN"
    
    mostrar_mensaje "Configurando variables de entorno para la sesión actual..."
    
    # Exportar variables para la sesión actual
    export NVM_DIR="$HOME/.nvm"
    
    # Cargar NVM si está disponible
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        source "$NVM_DIR/nvm.sh"
        mostrar_exito "NVM cargado en la sesión actual"
    else
        mostrar_advertencia "NVM no está disponible para carga inmediata"
    fi
}





################################################################################
#                          FUNCIONES DE VERIFICACIÓN POST-INSTALACIÓN         #
################################################################################

# Verificar que la instalación fue exitosa
verificar_instalacion_exitosa() {
    mostrar_seccion "VERIFICANDO INSTALACIÓN"
    
    # Recargar configuración
    source "$BASHRC_FILE" 2>/dev/null || true
    
    # Cargar NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Verificar NVM
    if command -v nvm >/dev/null 2>&1; then
        local version_nvm
        version_nvm=$(nvm --version 2>/dev/null || echo "No disponible")
        mostrar_exito "NVM está disponible: v$version_nvm"
    else
        mostrar_advertencia "NVM no está disponible en PATH actual"
        mostrar_mensaje "Esto es normal. Reinicia tu terminal para usar NVM"
    fi
    
    # Verificar Node.js
    if command -v node >/dev/null 2>&1; then
        local version_node
        version_node=$(node --version 2>/dev/null || echo "No disponible")
        mostrar_exito "Node.js está disponible: $version_node"
    else
        mostrar_mensaje "Node.js se instalará automáticamente al reiniciar el terminal"
    fi
    
    # Verificar NPM
    if command -v npm >/dev/null 2>&1; then
        local version_npm
        version_npm=$(npm --version 2>/dev/null || echo "No disponible")
        mostrar_exito "NPM está disponible: v$version_npm"
    fi
}

# Mostrar guía de uso y comandos básicos
mostrar_guia_uso() {
    mostrar_seccion "GUÍA DE USO DE NVM Y NODE.JS"
    
    echo -e "${VERDE}Comandos básicos de NVM:${NC}"
    echo ""
    echo -e "${CIAN}Ver versiones disponibles de Node.js:${NC}"
    echo "  nvm list-remote"
    echo ""
    echo -e "${CIAN}Instalar una versión específica:${NC}"
    echo "  nvm install 18.17.0"
    echo "  nvm install 20.5.0"
    echo ""
    echo -e "${CIAN}Ver versiones instaladas:${NC}"
    echo "  nvm list"
    echo ""
    echo -e "${CIAN}Cambiar a una versión específica:${NC}"
    echo "  nvm use 18.17.0"
    echo ""
    echo -e "${CIAN}Establecer versión por defecto:${NC}"
    echo "  nvm alias default 20.5.0"
    echo ""
    echo -e "${CIAN}Ver versión actual:${NC}"
    echo "  node --version"
    echo "  npm --version"
    echo ""
    echo -e "${VERDE}Comandos básicos de NPM:${NC}"
    echo ""
    echo -e "${CIAN}Instalar paquete globalmente:${NC}"
    echo "  npm install -g paquete"
    echo ""
    echo -e "${CIAN}Instalar paquete localmente:${NC}"
    echo "  npm install paquete"
    echo ""
    echo -e "${CIAN}Ver paquetes globales:${NC}"
    echo "  npm list -g --depth=0"
    echo ""
}

# Mostrar instrucciones finales
mostrar_instrucciones_finales() {
    mostrar_seccion "INSTALACIÓN COMPLETADA"
    
    echo -e "${VERDE}¡Instalación de Node.js y NVM completada exitosamente!${NC}"
    echo ""
    echo -e "${AMARILLO}PASOS SIGUIENTES:${NC}"
    echo "1. ${CIAN}Reinicia tu terminal${NC} o ejecuta: ${MORADO}source ~/.bashrc${NC}"
    echo "2. ${CIAN}Verifica la instalación${NC} con: ${MORADO}nvm --version${NC}"
    echo "3. ${CIAN}Verifica Node.js${NC} con: ${MORADO}node --version${NC}"
    echo "4. ${CIAN}Verifica NPM${NC} con: ${MORADO}npm --version${NC}"
    echo ""
    echo -e "${AMARILLO}WORKSPACE NODE.JS CONFIGURADO:${NC}"
    echo "• Runtime Configuration (RC) aplicada correctamente"
    echo "• Entorno de desarrollo Node.js listo para usar"
    echo "• Gestión de versiones múltiples habilitada"
    echo "• NPM configurado para gestión de paquetes"
    echo ""
    echo -e "${MORADO}[RC; Workspace Node.js]${NC} - Configuración completada por Rodolfo Casan"
}





################################################################################
#                              FUNCIÓN PRINCIPAL                              #
################################################################################

main() {
    # Mostrar banner inicial
    mostrar_banner
    
    # Solicitar confirmación antes de proceder
    solicitar_confirmacion
    
    # Verificaciones previas y detección inteligente
    mostrar_seccion "VERIFICACIONES PREVIAS"
    verificar_root
    verificar_sistema
    verificar_conexion
    
    # Detección inteligente de Node.js/NVM existente
    if detectar_nodejs_existente; then
        manejar_reinstalacion
    fi
    
    # Proceso de instalación
    instalar_dependencias_basicas
    instalar_nvm
    
    # Configuración del entorno
    configurar_entorno
    aplicar_configuracion
    
    # Instalar Node.js LTS
    instalar_nodejs_lts
    
    # Verificación final
    verificar_instalacion_exitosa
    mostrar_guia_uso
    mostrar_instrucciones_finales
    
    echo ""
    mostrar_exito "Script completado exitosamente"
}





# Ejecutar función principal con todos los argumentos
main "$@"