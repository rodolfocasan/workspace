#!/bin/bash

################################################################################
#                    INSTALADOR DE DOCKER PARA LINUX/DEBIAN                   #
################################################################################
# Descripción: Script inteligente de automatización para instalar Docker CE y Docker Compose
# Autor: Rodolfo Casan
# Versión: 1.0.0
# Ruta original del script: Linux/Debian/install_docker.sh
#
# Este script configura un entorno completo de contenedorización usando Docker CE
# y Docker Compose, permitiendo gestionar aplicaciones containerizadas de forma
# profesional en el workspace de desarrollo. Incluye detección inteligente de
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
readonly DOCKER_GPG_URL="https://download.docker.com/linux/debian/gpg"
readonly DOCKER_REPO_URL="https://download.docker.com/linux/debian"
readonly DOCKER_COMPOSE_BASE_URL="https://github.com/docker/compose/releases/latest/download"
readonly SCRIPT_VERSION="1.0.0"
readonly DOCKER_GROUP="docker"





################################################################################
#                            FUNCIONES DE UTILIDADES                          #
################################################################################

# Función para mostrar banner del script
mostrar_banner() {
    echo -e "${CIAN}"
    echo "=============================================================================="
    echo "                    INSTALADOR DE DOCKER PARA DEBIAN v${SCRIPT_VERSION}"
    echo "=============================================================================="
    echo -e "${NC}"
    echo -e "${MORADO}Desarrollado por Rodolfo Casan"
    echo ""
    echo "Este script configurará:"
    echo "• Docker CE (Community Edition)"
    echo "• Docker Compose"
    echo "• Configuración de usuario"
    echo "• Workspace de contenedorización completo"
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
        mostrar_mensaje "Ejecuta el script como usuario normal: ./install_docker.sh"
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
        mostrar_mensaje "Se requiere conexión a internet para descargar Docker"
        exit 1
    fi
    mostrar_exito "Conexión a internet verificada"
}

# Detectar y manejar instalaciones previas de Docker de forma inteligente
detectar_docker_existente() {
    local docker_detectado=false
    local version_docker=""
    local version_compose=""
    local servicio_activo=""
    
    mostrar_mensaje "Detectando instalaciones previas de Docker..."
    
    # Verificar si Docker está instalado
    if command -v docker >/dev/null 2>&1; then
        docker_detectado=true
        version_docker=$(docker --version 2>/dev/null || echo "Versión desconocida")
        
        # Verificar estado del servicio
        if systemctl is-active docker >/dev/null 2>&1; then
            servicio_activo="Activo"
        else
            servicio_activo="Inactivo"
        fi
    fi
    
    # Verificar Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        version_compose=$(docker-compose --version 2>/dev/null || echo "Versión desconocida")
    fi
    
    # Verificar paquetes instalados
    local paquetes_docker=()
    local paquetes_posibles=(
        "docker-ce"
        "docker.io"
        "docker"
        "docker-engine"
    )
    
    for paquete in "${paquetes_posibles[@]}"; do
        if dpkg -l | grep -q "^ii.*$paquete" 2>/dev/null; then
            paquetes_docker+=("$paquete")
        fi
    done
    
    # Verificar grupo docker
    local usuario_en_grupo=""
    if groups | grep -q docker 2>/dev/null; then
        usuario_en_grupo="Sí"
    else
        usuario_en_grupo="No"
    fi
    
    # Mostrar resultados de la detección
    if [ "$docker_detectado" = true ] || [ ${#paquetes_docker[@]} -gt 0 ]; then
        echo ""
        mostrar_advertencia "¡DOCKER YA ESTÁ INSTALADO EN EL SISTEMA!"
        echo ""
        echo -e "${AMARILLO}=== INFORMACIÓN DE LA INSTALACIÓN ACTUAL ===${NC}"
        
        if [ -n "$version_docker" ]; then
            echo -e "${CIAN}Docker instalado:${NC} $version_docker"
        fi
        
        if [ -n "$version_compose" ]; then
            echo -e "${CIAN}Docker Compose:${NC} $version_compose"
        else
            echo -e "${CIAN}Docker Compose:${NC} ✗ No instalado"
        fi
        
        if [ -n "$servicio_activo" ]; then
            echo -e "${CIAN}Servicio Docker:${NC} $servicio_activo"
        fi
        
        echo -e "${CIAN}Usuario en grupo docker:${NC} $usuario_en_grupo"
        
        if [ ${#paquetes_docker[@]} -gt 0 ]; then
            echo -e "${CIAN}Paquetes instalados:${NC}"
            for paquete in "${paquetes_docker[@]}"; do
                echo "  • $paquete"
            done
        fi
        
        echo ""
        return 0
    else
        mostrar_exito "No se detectó ninguna instalación previa de Docker"
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
    echo -e "${VERDE}2)${NC} Reparar/Completar instalación existente"
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
                mostrar_mensaje "Procediendo con reparación/completar instalación..."
                reparar_instalacion
                return 0
                ;;
            3)
                mostrar_advertencia "¡ATENCIÓN! Esto eliminará COMPLETAMENTE tu instalación actual de Docker"
                echo -e "${ROJO}Se perderán:${NC}"
                echo "  • Todas las imágenes descargadas"
                echo "  • Contenedores existentes"
                echo "  • Volúmenes y redes creadas"
                echo "  • Configuraciones personalizadas"
                echo ""
                echo -e "${AMARILLO}¿Estás SEGURO de que deseas continuar? (escribe 'CONFIRMAR' para proceder):${NC}"
                read -r confirmacion
                
                if [ "$confirmacion" = "CONFIRMAR" ]; then
                    eliminar_docker_completo
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
    
    if command -v docker >/dev/null 2>&1; then
        local version=$(docker --version)
        mostrar_exito "Docker funcionando: $version"
        
        # Probar conexión con daemon
        if docker info >/dev/null 2>&1; then
            mostrar_exito "Daemon de Docker funcionando correctamente"
        else
            mostrar_advertencia "Docker instalado pero daemon no accesible sin sudo"
        fi
    fi
    
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version)
        mostrar_exito "Docker Compose funcionando: $compose_version"
    else
        mostrar_advertencia "Docker Compose no está instalado"
    fi
}

# Reparar/completar instalación existente
reparar_instalacion() {
    mostrar_seccion "REPARANDO/COMPLETANDO INSTALACIÓN"
    
    # Verificar e instalar Docker Compose si no está
    if ! command -v docker-compose >/dev/null 2>&1; then
        mostrar_mensaje "Instalando Docker Compose faltante..."
        instalar_docker_compose
    fi
    
    # Verificar y agregar usuario al grupo docker
    if ! groups | grep -q docker 2>/dev/null; then
        mostrar_mensaje "Agregando usuario al grupo docker..."
        configurar_permisos_usuario
    fi
    
    # Verificar servicio
    mostrar_mensaje "Verificando servicio Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    verificar_instalacion_exitosa
    mostrar_exito "Reparación/completado exitoso"
}

# Eliminar completamente Docker
eliminar_docker_completo() {
    mostrar_seccion "ELIMINANDO INSTALACIÓN COMPLETA"
    
    # Detener servicio
    mostrar_mensaje "Deteniendo servicio Docker..."
    sudo systemctl stop docker 2>/dev/null || true
    
    # Eliminar paquetes
    mostrar_mensaje "Eliminando paquetes de Docker..."
    sudo apt purge -y docker-ce docker-ce-cli containerd.io docker.io docker docker-engine 2>/dev/null || true
    
    # Eliminar Docker Compose
    if [ -f "/usr/local/bin/docker-compose" ]; then
        mostrar_mensaje "Eliminando Docker Compose..."
        sudo rm -f /usr/local/bin/docker-compose
    fi
    
    # Eliminar directorios y datos
    mostrar_mensaje "Eliminando datos y configuraciones..."
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    sudo rm -rf /etc/docker
    
    # Remover repositorio
    sudo rm -f /etc/apt/sources.list.d/docker.list
    
    # Actualizar repositorios
    sudo apt update
    
    mostrar_exito "Docker eliminado completamente del sistema"
    mostrar_mensaje "Procediendo con instalación limpia..."
}





################################################################################
#                        FUNCIONES DE INSTALACIÓN                             #
################################################################################

# Actualizar repositorios del sistema
actualizar_repositorios() {
    mostrar_seccion "ACTUALIZANDO SISTEMA"
    
    mostrar_mensaje "Actualizando listas de paquetes y sistema..."
    if sudo apt update && sudo apt upgrade -y; then
        mostrar_exito "Sistema actualizado correctamente"
    else
        mostrar_error "Falló la actualización del sistema"
        exit 1
    fi
}

# Instalar dependencias necesarias para Docker
instalar_dependencias() {
    mostrar_seccion "INSTALANDO DEPENDENCIAS"
    
    mostrar_mensaje "Instalando herramientas necesarias para Docker..."
    
    local dependencias=(
        "apt-transport-https"
        "ca-certificates" 
        "curl"
        "software-properties-common"
        "gnupg2"
        "lsb-release"
    )
    
    mostrar_mensaje "Instalando ${#dependencias[@]} paquetes de dependencias..."
    
    if sudo apt install -y "${dependencias[@]}"; then
        mostrar_exito "Todas las dependencias fueron instaladas correctamente"
    else
        mostrar_error "Falló la instalación de dependencias"
        exit 1
    fi
}

# Configurar repositorio oficial de Docker
configurar_repositorio_docker() {
    mostrar_seccion "CONFIGURANDO REPOSITORIO DOCKER"
    
    # Agregar clave GPG oficial de Docker
    mostrar_mensaje "Agregando clave GPG oficial de Docker..."
    if curl -fsSL "$DOCKER_GPG_URL" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
        mostrar_exito "Clave GPG agregada correctamente"
    else
        mostrar_error "Falló la descarga de la clave GPG"
        exit 1
    fi
    
    # Agregar repositorio Docker
    mostrar_mensaje "Agregando repositorio Docker a APT..."
    local codename
    codename=$(lsb_release -cs)
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $DOCKER_REPO_URL $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    if [ $? -eq 0 ]; then
        mostrar_exito "Repositorio Docker configurado para: $codename"
    else
        mostrar_error "Falló la configuración del repositorio"
        exit 1
    fi
    
    # Actualizar índice de paquetes
    mostrar_mensaje "Actualizando índice de paquetes..."
    if sudo apt update; then
        mostrar_exito "Índice actualizado correctamente"
    else
        mostrar_error "Falló la actualización del índice"
        exit 1
    fi
}

# Instalar Docker CE
instalar_docker_ce() {
    mostrar_seccion "INSTALANDO DOCKER CE"
    
    mostrar_mensaje "Instalando Docker CE (Community Edition)..."
    
    if sudo apt install -y docker-ce docker-ce-cli containerd.io; then
        mostrar_exito "Docker CE instalado correctamente"
        
        # Verificar instalación
        local docker_version
        docker_version=$(docker --version 2>/dev/null || echo "Error al obtener versión")
        mostrar_mensaje "Versión instalada: $docker_version"
    else
        mostrar_error "Falló la instalación de Docker CE"
        exit 1
    fi
}

# Instalar Docker Compose
instalar_docker_compose() {
    mostrar_seccion "INSTALANDO DOCKER COMPOSE"
    
    mostrar_mensaje "Descargando Docker Compose desde GitHub..."
    
    # Obtener arquitectura del sistema
    local arch
    arch=$(uname -m)
    local system
    system=$(uname -s)
    
    # Construir URL de descarga
    local compose_url="${DOCKER_COMPOSE_BASE_URL}/docker-compose-${system}-${arch}"
    
    mostrar_mensaje "URL de descarga: $compose_url"
    
    if sudo curl -L "$compose_url" -o /usr/local/bin/docker-compose; then
        mostrar_exito "Docker Compose descargado correctamente"
    else
        mostrar_error "Falló la descarga de Docker Compose"
        exit 1
    fi
    
    # Dar permisos de ejecución
    mostrar_mensaje "Configurando permisos de ejecución..."
    if sudo chmod +x /usr/local/bin/docker-compose; then
        mostrar_exito "Permisos configurados correctamente"
        
        # Verificar instalación
        local compose_version
        compose_version=$(docker-compose --version 2>/dev/null || echo "Error al obtener versión")
        mostrar_mensaje "Versión instalada: $compose_version"
    else
        mostrar_error "Falló la configuración de permisos"
        exit 1
    fi
}





################################################################################
#                         FUNCIONES DE CONFIGURACIÓN                          #
################################################################################

# Configurar servicio Docker
configurar_servicio() {
    mostrar_seccion "CONFIGURANDO SERVICIO DOCKER"
    
    mostrar_mensaje "Habilitando Docker para iniciar automáticamente..."
    if sudo systemctl enable docker; then
        mostrar_exito "Servicio habilitado para arranque automático"
    else
        mostrar_advertencia "No se pudo habilitar arranque automático"
    fi
    
    mostrar_mensaje "Iniciando servicio Docker..."
    if sudo systemctl start docker; then
        mostrar_exito "Servicio Docker iniciado correctamente"
    else
        mostrar_error "Falló el inicio del servicio Docker"
        exit 1
    fi
    
    # Verificar estado del servicio
    if systemctl is-active docker >/dev/null 2>&1; then
        mostrar_exito "Servicio Docker está activo y funcionando"
    else
        mostrar_error "Servicio Docker no está activo"
        exit 1
    fi
}

# Configurar permisos de usuario
configurar_permisos_usuario() {
    mostrar_seccion "CONFIGURANDO PERMISOS DE USUARIO"
    
    # Crear grupo docker si no existe
    if ! getent group "$DOCKER_GROUP" >/dev/null 2>&1; then
        mostrar_mensaje "Creando grupo docker..."
        sudo groupadd "$DOCKER_GROUP"
    fi
    
    # Agregar usuario actual al grupo docker
    local usuario_actual
    usuario_actual=$(whoami)
    
    mostrar_mensaje "Agregando usuario '$usuario_actual' al grupo docker..."
    if sudo usermod -aG "$DOCKER_GROUP" "$usuario_actual"; then
        mostrar_exito "Usuario agregado al grupo docker correctamente"
        mostrar_advertencia "Debes cerrar sesión y volver a iniciar para que los cambios tomen efecto"
        mostrar_mensaje "Alternativamente, ejecuta: newgrp docker"
    else
        mostrar_error "Falló al agregar usuario al grupo docker"
        exit 1
    fi
}





################################################################################
#                          FUNCIONES DE VERIFICACIÓN POST-INSTALACIÓN         #
################################################################################

# Verificar que la instalación fue exitosa
verificar_instalacion_exitosa() {
    mostrar_seccion "VERIFICANDO INSTALACIÓN"
    
    # Verificar Docker
    if command -v docker >/dev/null 2>&1; then
        local docker_version
        docker_version=$(docker --version 2>/dev/null || echo "No disponible")
        mostrar_exito "Docker disponible: $docker_version"
        
        # Probar funcionalidad básica
        mostrar_mensaje "Probando funcionalidad básica de Docker..."
        if sudo docker run hello-world >/dev/null 2>&1; then
            mostrar_exito "Docker funciona correctamente (test con hello-world exitoso)"
        else
            mostrar_advertencia "Docker instalado pero test básico falló"
        fi
    else
        mostrar_error "Docker no está disponible"
        exit 1
    fi
    
    # Verificar Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker-compose --version 2>/dev/null || echo "No disponible")
        mostrar_exito "Docker Compose disponible: $compose_version"
    else
        mostrar_advertencia "Docker Compose no está disponible"
    fi
    
    # Verificar servicio
    if systemctl is-active docker >/dev/null 2>&1; then
        mostrar_exito "Servicio Docker activo y funcionando"
    else
        mostrar_advertencia "Servicio Docker no está activo"
    fi
}

# Mostrar guía de uso y comandos básicos
mostrar_guia_uso() {
    mostrar_seccion "GUÍA DE USO DE DOCKER"
    
    echo -e "${VERDE}Comandos básicos de Docker:${NC}"
    echo ""
    echo -e "${CIAN}Ver información del sistema:${NC}"
    echo "  docker info"
    echo ""
    echo -e "${CIAN}Listar imágenes disponibles:${NC}"
    echo "  docker images"
    echo ""
    echo -e "${CIAN}Descargar una imagen:${NC}"
    echo "  docker pull nginx"
    echo "  docker pull ubuntu:20.04"
    echo ""
    echo -e "${CIAN}Ejecutar un contenedor:${NC}"
    echo "  docker run -d -p 80:80 nginx"
    echo "  docker run -it ubuntu:20.04 bash"
    echo ""
    echo -e "${CIAN}Listar contenedores:${NC}"
    echo "  docker ps                 # activos"
    echo "  docker ps -a              # todos"
    echo ""
    echo -e "${CIAN}Detener/eliminar contenedores:${NC}"
    echo "  docker stop <container_id>"
    echo "  docker rm <container_id>"
    echo ""
    echo -e "${VERDE}Comandos de Docker Compose:${NC}"
    echo ""
    echo -e "${CIAN}Ejecutar servicios definidos:${NC}"
    echo "  docker-compose up"
    echo "  docker-compose up -d      # en segundo plano"
    echo ""
    echo -e "${CIAN}Detener servicios:${NC}"
    echo "  docker-compose down"
    echo ""
}

# Mostrar instrucciones finales
mostrar_instrucciones_finales() {
    mostrar_seccion "INSTALACIÓN COMPLETADA"
    
    echo -e "${VERDE}¡Instalación de Docker completada exitosamente!${NC}"
    echo ""
    echo -e "${AMARILLO}PASOS SIGUIENTES:${NC}"
    echo "1. ${CIAN}Cerrar sesión y volver a iniciar${NC} o ejecutar: ${MORADO}newgrp docker${NC}"
    echo "2. ${CIAN}Verificar la instalación${NC} con: ${MORADO}docker --version${NC}"
    echo "3. ${CIAN}Probar Docker${NC} sin sudo: ${MORADO}docker run hello-world${NC}"
    echo "4. ${CIAN}Probar Docker Compose${NC} con: ${MORADO}docker-compose --version${NC}"
    echo ""
    echo -e "${AMARILLO}WORKSPACE DE CONTENEDORIZACIÓN CONFIGURADO:${NC}"
    echo "• Runtime Configuration (RC) aplicada correctamente"
    echo "• Entorno Docker CE listo para desarrollo"
    echo "• Docker Compose instalado para aplicaciones multi-container"
    echo "• Permisos de usuario configurados correctamente"
    echo ""
    echo -e "${MORADO}[RC; Workspace Docker]${NC} - Configuración completada por Rodolfo Casan"
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
    
    # Detección inteligente de Docker existente
    if detectar_docker_existente; then
        manejar_reinstalacion
    fi
    
    # Proceso de instalación
    actualizar_repositorios
    instalar_dependencias
    configurar_repositorio_docker
    instalar_docker_ce
    instalar_docker_compose
    
    # Configuración del entorno
    configurar_servicio
    configurar_permisos_usuario
    
    # Verificación final
    verificar_instalacion_exitosa
    mostrar_guia_uso
    mostrar_instrucciones_finales
    
    echo ""
    mostrar_exito "Script completado exitosamente"
}





# Ejecutar función principal con todos los argumentos
main "$@"