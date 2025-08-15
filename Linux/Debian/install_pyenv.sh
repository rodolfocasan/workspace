#!/bin/bash

################################################################################
#                    INSTALADOR DE PYENV PARA LINUX/DEBIAN                    #
################################################################################
# Descripción: Script inteligente de automatización para instalar Pyenv y sus dependencias
# Autor: Rodolfo Casan
# Versión: 1.0.0
# Ruta original del script: Linux/Debian/install_pyenv.sh
#
# Este script configura un entorno completo de desarrollo Python usando Pyenv,
# permitiendo gestionar múltiples versiones de Python de forma aislada y
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
readonly PYENV_REPO="https://github.com/pyenv/pyenv.git"
readonly PYENV_DIR="$HOME/.pyenv"
readonly BASHRC_FILE="$HOME/.bashrc"
readonly SCRIPT_VERSION="1.0.0"





################################################################################
#                            FUNCIONES DE UTILIDADES                          #
################################################################################

# Función para mostrar banner del script
mostrar_banner() {
    echo -e "${CIAN}"
    echo "=============================================================================="
    echo "                    INSTALADOR DE PYENV PARA DEBIAN v${SCRIPT_VERSION}"
    echo "=============================================================================="
    echo -e "${NC}"
    echo -e "${MORADO}Desarrollado por Rodolfo Casan"
    echo ""
    echo "Este script configurará:"
    echo "• Pyenv (Python Version Management)"
    echo "• Dependencias de compilación"
    echo "• Variables de entorno"
    echo "• Workspace Python completo"
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
        mostrar_mensaje "Ejecuta el script como usuario normal: ./install_pyenv.sh"
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
        mostrar_mensaje "Se requiere conexión a internet para descargar Pyenv y dependencias"
        exit 1
    fi
    mostrar_exito "Conexión a internet verificada"
}

# Detectar y manejar instalaciones previas de Pyenv de forma inteligente
detectar_pyenv_existente() {
    local pyenv_detectado=false
    local version_actual=""
    local ubicacion_pyenv=""
    local pythons_instalados=()
    
    mostrar_mensaje "Detectando instalaciones previas de Pyenv..."
    
    # Verificar múltiples ubicaciones posibles de Pyenv
    local ubicaciones_posibles=(
        "$HOME/.pyenv"
        "/opt/pyenv"
        "/usr/local/pyenv"
    )
    
    # Verificar si pyenv está en PATH
    if command -v pyenv >/dev/null 2>&1; then
        pyenv_detectado=true
        version_actual=$(pyenv --version 2>/dev/null || echo "Versión desconocida")
        ubicacion_pyenv=$(command -v pyenv)
        
        # Obtener versiones de Python instaladas
        if pyenv versions >/dev/null 2>&1; then
            mapfile -t pythons_instalados < <(pyenv versions --bare 2>/dev/null | grep -v "system" || true)
        fi
    fi
    
    # Verificar directorios físicos
    for ubicacion in "${ubicaciones_posibles[@]}"; do
        if [ -d "$ubicacion" ]; then
            pyenv_detectado=true
            if [ -z "$ubicacion_pyenv" ]; then
                ubicacion_pyenv="$ubicacion"
            fi
            # Verificar si hay versiones de Python instaladas en esta ubicación
            if [ -d "$ubicacion/versions" ] && [ -n "$(ls -A "$ubicacion/versions" 2>/dev/null)" ]; then
                mapfile -t pythons_instalados < <(ls "$ubicacion/versions" 2>/dev/null || true)
            fi
        fi
    done
    
    # Verificar configuración en archivos de shell
    local archivos_config=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    local configuracion_encontrada=false
    for archivo in "${archivos_config[@]}"; do
        if [ -f "$archivo" ] && grep -q "PYENV_ROOT\|pyenv init" "$archivo" 2>/dev/null; then
            configuracion_encontrada=true
            break
        fi
    done
    
    # Mostrar resultados de la detección
    if [ "$pyenv_detectado" = true ]; then
        echo ""
        mostrar_advertencia "¡PYENV YA ESTÁ INSTALADO EN EL SISTEMA!"
        echo ""
        echo -e "${AMARILLO}=== INFORMACIÓN DE LA INSTALACIÓN ACTUAL ===${NC}"
        
        if [ -n "$version_actual" ]; then
            echo -e "${CIAN}Versión instalada:${NC} $version_actual"
        fi
        
        if [ -n "$ubicacion_pyenv" ]; then
            echo -e "${CIAN}Ubicación:${NC} $ubicacion_pyenv"
        fi
        
        if [ "$configuracion_encontrada" = true ]; then
            echo -e "${CIAN}Configuración en shell:${NC} ✓ Detectada"
        else
            echo -e "${CIAN}Configuración en shell:${NC} ✗ No detectada o incompleta"
        fi
        
        if [ ${#pythons_instalados[@]} -gt 0 ]; then
            echo -e "${CIAN}Versiones de Python instaladas (${#pythons_instalados[@]}):${NC}"
            for python_version in "${pythons_instalados[@]}"; do
                echo "  • $python_version"
            done
        else
            echo -e "${CIAN}Versiones de Python:${NC} Ninguna instalada"
        fi
        
        echo ""
        return 0
    else
        mostrar_exito "No se detectó ninguna instalación previa de Pyenv"
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
                mostrar_advertencia "¡ATENCIÓN! Esto eliminará COMPLETAMENTE tu instalación actual de Pyenv"
                echo -e "${ROJO}Se perderán:${NC}"
                echo "  • Todas las versiones de Python instaladas"
                echo "  • Configuraciones personalizadas"
                echo "  • Entornos virtuales creados con pyenv-virtualenv"
                echo ""
                echo -e "${AMARILLO}¿Estás SEGURO de que deseas continuar? (escribe 'CONFIRMAR' para proceder):${NC}"
                read -r confirmacion
                
                if [ "$confirmacion" = "CONFIRMAR" ]; then
                    eliminar_pyenv_completo
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
    
    if command -v pyenv >/dev/null 2>&1; then
        local version=$(pyenv --version)
        mostrar_exito "Pyenv funcionando correctamente: $version"
        
        # Verificar versión global
        local version_global
        version_global=$(pyenv global 2>/dev/null || echo "No configurada")
        mostrar_mensaje "Versión global de Python: $version_global"
        
        # Verificar versiones disponibles
        local total_versiones
        total_versiones=$(pyenv versions --bare 2>/dev/null | grep -v "system" | wc -l || echo "0")
        mostrar_mensaje "Total de versiones de Python instaladas: $total_versiones"
        
    else
        mostrar_advertencia "Pyenv instalado pero no disponible en PATH"
        mostrar_mensaje "Es posible que necesites reiniciar tu terminal"
    fi
}

# Reparar instalación existente
reparar_instalacion() {
    mostrar_seccion "REPARANDO INSTALACIÓN DE PYENV"
    
    # Actualizar repositorio existente
    if [ -d "$PYENV_DIR/.git" ]; then
        mostrar_mensaje "Actualizando Pyenv a la última versión..."
        cd "$PYENV_DIR"
        if git pull origin master; then
            mostrar_exito "Pyenv actualizado correctamente"
        else
            mostrar_advertencia "No se pudo actualizar Pyenv (posiblemente ya está actualizado)"
        fi
        cd - >/dev/null
    fi
    
    # Verificar y reparar configuración
    mostrar_mensaje "Verificando configuración en .bashrc..."
    if ! grep -q "PYENV_ROOT.*$HOME/.pyenv" "$BASHRC_FILE" 2>/dev/null; then
        mostrar_mensaje "Agregando configuración faltante..."
        configurar_entorno
    else
        mostrar_exito "Configuración de .bashrc está correcta"
    fi
    
    # Reinstalar dependencias por si acaso
    mostrar_mensaje "Verificando dependencias del sistema..."
    instalar_dependencias
    
    # Aplicar configuración
    aplicar_configuracion
    verificar_instalacion_exitosa
    
    mostrar_exito "Reparación/actualización completada"
}

# Eliminar completamente Pyenv
eliminar_pyenv_completo() {
    mostrar_seccion "ELIMINANDO INSTALACIÓN COMPLETA"
    
    mostrar_mensaje "Eliminando directorio de Pyenv..."
    
    # Eliminar directorios de Pyenv
    local directorios_eliminar=(
        "$HOME/.pyenv"
        "/opt/pyenv"
        "/usr/local/pyenv"
    )
    
    for directorio in "${directorios_eliminar[@]}"; do
        if [ -d "$directorio" ]; then
            mostrar_mensaje "Eliminando: $directorio"
            rm -rf "$directorio"
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
            # Crear backup antes de limpiar
            cp "$archivo" "${archivo}.backup_pre_reinstall_$(date +%Y%m%d_%H%M%S)"
            
            # Eliminar líneas relacionadas con Pyenv
            sed -i '/# Configuración de Pyenv/,/################################################################################/d' "$archivo" 2>/dev/null || true
            sed -i '/PYENV_ROOT/d; /pyenv init/d' "$archivo" 2>/dev/null || true
            
            mostrar_mensaje "Limpiado: $archivo"
        fi
    done
    
    mostrar_exito "Pyenv eliminado completamente del sistema"
    mostrar_mensaje "Procediendo con instalación limpia..."
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

# Instalar dependencias necesarias para Pyenv
instalar_dependencias() {
    mostrar_seccion "INSTALANDO DEPENDENCIAS"
    
    mostrar_mensaje "Instalando herramientas de compilación y librerías necesarias..."
    
    local dependencias=(
        # Herramientas de compilación básicas
        "make"
        "build-essential"
        "git"
        "curl"
        "wget"
        
        # Librerías de desarrollo SSL/TLS
        "libssl-dev"
        
        # Librerías de compresión
        "zlib1g-dev"
        "libbz2-dev"
        "liblzma-dev"
        "xz-utils"
        
        # Librerías de readline y sqlite
        "libreadline-dev"
        "libsqlite3-dev"
        
        # Herramientas LLVM
        "llvm"
        
        # Librerías ncurses
        "libncurses5-dev"
        "libncursesw5-dev"
        
        # Librerías adicionales
        "tk-dev"
        "libffi-dev"
        "python3-openssl"
    )
    
    mostrar_mensaje "Instalando ${#dependencias[@]} paquetes de dependencias..."
    
    if sudo apt install -y "${dependencias[@]}"; then
        mostrar_exito "Todas las dependencias fueron instaladas correctamente"
    else
        mostrar_error "Falló la instalación de dependencias"
        exit 1
    fi
}

# Descargar e instalar Pyenv
instalar_pyenv() {
    mostrar_seccion "DESCARGANDO E INSTALANDO PYENV"
    
    mostrar_mensaje "Clonando repositorio oficial de Pyenv desde GitHub..."
    mostrar_mensaje "Repositorio: $PYENV_REPO"
    mostrar_mensaje "Directorio destino: $PYENV_DIR"
    
    if git clone "$PYENV_REPO" "$PYENV_DIR"; then
        mostrar_exito "Pyenv descargado e instalado correctamente"
        
        # Mostrar información de la versión instalada
        local pyenv_version
        pyenv_version=$(cd "$PYENV_DIR" && git describe --tags 2>/dev/null || echo "desarrollo")
        mostrar_mensaje "Versión de Pyenv instalada: $pyenv_version"
    else
        mostrar_error "Falló la descarga de Pyenv"
        exit 1
    fi
}





################################################################################
#                         FUNCIONES DE CONFIGURACIÓN                          #
################################################################################

# Configurar variables de entorno y PATH
configurar_entorno() {
    mostrar_seccion "CONFIGURANDO ENTORNO"
    
    # Crear backup del .bashrc
    if [ -f "$BASHRC_FILE" ]; then
        local backup_file="${BASHRC_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$BASHRC_FILE" "$backup_file"
        mostrar_mensaje "Backup creado: $backup_file"
    fi
    
    # Verificar si la configuración ya existe
    if grep -q "PYENV_ROOT" "$BASHRC_FILE" 2>/dev/null; then
        mostrar_advertencia "Configuración de Pyenv ya presente en $BASHRC_FILE"
        mostrar_mensaje "Saltando configuración de variables de entorno"
    else
        mostrar_mensaje "Agregando configuración de Pyenv a $BASHRC_FILE..."
        
        # Agregar configuración completa de Pyenv
        cat >> "$BASHRC_FILE" << 'EOF'

################################################################################
# Configuración de Pyenv - [Rodolfo Casan; Workspace Python]
# Agregado automáticamente por el instalador de Pyenv
################################################################################

# Definir directorio raíz de Pyenv
export PYENV_ROOT="$HOME/.pyenv"

# Agregar binarios de Pyenv al PATH
export PATH="$PYENV_ROOT/bin:$PATH"

# Inicializar Pyenv automáticamente
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
fi

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
    export PYENV_ROOT="$PYENV_DIR"
    export PATH="$PYENV_ROOT/bin:$PATH"
    
    # Inicializar pyenv si está disponible
    if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
        eval "$(pyenv init --path)" 2>/dev/null || true
        eval "$(pyenv init -)" 2>/dev/null || true
        mostrar_exito "Pyenv inicializado en la sesión actual"
    else
        mostrar_advertencia "Pyenv no está disponible para inicialización inmediata"
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
    
    # Verificar disponibilidad del comando pyenv
    if command -v pyenv >/dev/null 2>&1; then
        local version
        version=$(pyenv --version 2>/dev/null || echo "No disponible")
        mostrar_exito "Pyenv está disponible: $version"
        
        # Verificar funcionalidad básica
        mostrar_mensaje "Probando funcionalidad básica de Pyenv..."
        if pyenv commands >/dev/null 2>&1; then
            mostrar_exito "Pyenv funciona correctamente"
        else
            mostrar_advertencia "Pyenv instalado pero con posibles problemas"
        fi
    else
        mostrar_advertencia "Pyenv no está disponible en PATH actual"
        mostrar_mensaje "Esto es normal. Reinicia tu terminal para usar Pyenv"
    fi
}

# Mostrar guía de uso y comandos básicos
mostrar_guia_uso() {
    mostrar_seccion "GUÍA DE USO DE PYENV"
    
    echo -e "${VERDE}Comandos básicos de Pyenv:${NC}"
    echo ""
    echo -e "${CIAN}Listar versiones disponibles:${NC}"
    echo "  pyenv install --list"
    echo ""
    echo -e "${CIAN}Instalar una versión de Python:${NC}"
    echo "  pyenv install 3.11.0"
    echo "  pyenv install 3.12.0"
    echo ""
    echo -e "${CIAN}Ver versiones instaladas:${NC}"
    echo "  pyenv versions"
    echo ""
    echo -e "${CIAN}Establecer versión global:${NC}"
    echo "  pyenv global 3.11.0"
    echo ""
    echo -e "${CIAN}Establecer versión local (por proyecto):${NC}"
    echo "  pyenv local 3.12.0"
    echo ""
    echo -e "${CIAN}Ver versión actual:${NC}"
    echo "  pyenv version"
    echo ""
    echo -e "${CIAN}Ver ruta del Python actual:${NC}"
    echo "  pyenv which python"
    echo ""
}

# Mostrar instrucciones finales
mostrar_instrucciones_finales() {
    mostrar_seccion "INSTALACIÓN COMPLETADA"
    
    echo -e "${VERDE}¡Instalación de Pyenv completada exitosamente!${NC}"
    echo ""
    echo -e "${AMARILLO}PASOS SIGUIENTES:${NC}"
    echo "1. ${CIAN}Reinicia tu terminal${NC} o ejecuta: ${MORADO}source ~/.bashrc${NC}"
    echo "2. ${CIAN}Verifica la instalación${NC} con: ${MORADO}pyenv --version${NC}"
    echo "3. ${CIAN}Instala tu primera versión de Python${NC}: ${MORADO}pyenv install 3.11.0${NC}"
    echo ""
    echo -e "${AMARILLO}WORKSPACE PYTHON CONFIGURADO:${NC}"
    echo "• Runtime Configuration (RC) aplicada correctamente"
    echo "• Entorno de desarrollo Python listo para usar"
    echo "• Gestión de versiones múltiples habilitada"
    echo ""
    echo -e "${MORADO}[RC; Workspace Python]${NC} - Configuración completada por Rodolfo Casan"
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
    
    # Detección inteligente de Pyenv existente
    if detectar_pyenv_existente; then
        manejar_reinstalacion
    fi
    
    # Proceso de instalación
    actualizar_repositorios
    instalar_dependencias
    instalar_pyenv
    
    # Configuración del entorno
    configurar_entorno
    aplicar_configuracion
    
    # Verificación final
    verificar_instalacion_exitosa
    mostrar_guia_uso
    mostrar_instrucciones_finales
    
    echo ""
    mostrar_exito "Script completado exitosamente"
}





# Ejecutar función principal con todos los argumentos
main "$@"