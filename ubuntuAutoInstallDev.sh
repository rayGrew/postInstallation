#!/usr/bin/env bash
# =============================================================================
# Ubuntu 24.04 LTS - Instalación automática (General + Dev)
# - Actualiza sistema
# - Habilita Flatpak + Flathub
# - Instala/gestiona (con detección y migración de método si aplica):
#   LibreOffice (apt), Zoom (flatpak), VS Code (apt repo MS), Cursor (.deb),
#   Zen Browser (flatpak), Thunderbird (flatpak), DBeaver CE (flatpak),
#   Termius (flatpak), Postman (flatpak), Insomnia (flatpak)
# - Docker CE (repo oficial) + compose plugin, servicio y grupo
# - Logs detallados en /var/log/ubuntu_setup_*.log
# - Mensajes con colores y [OK]/[ERROR]
# - Reinicia al final (configurable)
# =============================================================================
set -euo pipefail

# ======================= Config =======================
DEBIAN_FRONTEND=noninteractive
AUTO_REBOOT=true           # Reiniciar al final
REBOOT_SECONDS=10          # Cuenta regresiva
INSTALL_API_CLIENTS="both" # opciones: postman|insomnia|both
LOG_DIR="/var/log"
TS="$(date +'%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/ubuntu_setup_${TS}.log"

# (Opcional) Forzar URL de Cursor .deb:
# export CURSOR_DEB_URL="https://download.cursor.sh/linux/cursor-x.y.z-amd64.deb"

# ======================= Colores =======================
C_RESET="\033[0m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_CYAN="\033[0;36m"
C_YELLOW="\033[1;33m"
C_GRAY="\033[0;37m"

# ======================= Utils base =======================
must_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${C_RED}ERROR:${C_RESET} ejecuta este script con sudo o como root."
    exit 1
  fi
}
prep_log() { mkdir -p "${LOG_DIR}"; touch "${LOG_FILE}"; chmod 0644 "${LOG_FILE}"; }
log()      { local level="${2:-INFO}"; echo "[$(date +'%F %T')] ${level^^} - $1" | tee -a "${LOG_FILE}" >/dev/null; }
ok()       { echo -e "  ${C_GREEN}[OK]${C_RESET} $1";   log "$1" "OK"; }
error()    { echo -e "  ${C_RED}[ERROR]${C_RESET} $1"; log "$1" "ERROR"; }
info()     { echo -e "${C_CYAN}==> $1${C_RESET}";       log "$1" "INFO"; }
warn()     { echo -e "  ${C_YELLOW}[WARN]${C_RESET} $1"; log "$1" "WARN"; }
run() {
  local desc="$1"; shift
  info "${desc}"
  if "$@" 2>&1 | tee -a "${LOG_FILE}"; then ok "${desc}"; else error "${desc}"; return 1; fi
}
section() {
  echo -e "\n${C_YELLOW}====================================================${C_RESET}"
  echo -e "${C_YELLOW}$1${C_RESET}"
  echo -e "${C_YELLOW}====================================================${C_RESET}"
  log "=== $1 ==="
}
trap 'error "Fallo en la línea $LINENO. Revisa el log: ${LOG_FILE}"' ERR

# ======================= Helpers de apps (detección/migración) =======================
prompt_yes_no() {
  local ans
  while true; do
    read -r -p "$1 [s/N]: " ans
    case "${ans,,}" in
      s|si|sí|y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) echo "Responde s/N" ;;
    esac
  done
}
is_installed_cmd() { command -v "$1" >/dev/null 2>&1; }
is_installed_apt() { dpkg -s "$1" >/dev/null 2>&1; }
remove_apt() {
  run "Quitar $1 (apt)" apt-get purge -y "$1" || true
  run "Auto-remove dependencias apt" apt-get autoremove -yq || true
}
is_installed_flatpak() { flatpak list --app --columns=application | grep -Fxq "$1"; }
remove_flatpak() { run "Quitar $1 (Flatpak)" flatpak uninstall -y "$1" || true; }
is_installed_snap() { command -v snap >/dev/null 2>&1 && snap list | awk '{print $1}' | grep -Fxq "$1"; }
remove_snap() { run "Quitar $1 (Snap)" snap remove "$1" || true; }

# Asegura una app con método deseado, migrando si procede.
# ensure_app "Nombre" "apt|flatpak|deb" "apt_pkg" "flatpak_id" "snap_pkg" "check_cmd" "install_fn_for_deb"
ensure_app() {
  local NAME="$1" WANT="$2" APT_PKG="$3" FLATPAK_ID="$4" SNAP_PKG="$5" CHECK_CMD="$6" INSTALL_FN="$7"
  section "$NAME"

  # 1) ¿Ya está por el método deseado?
  case "$WANT" in
    apt)     if [[ -n "$APT_PKG" ]] && is_installed_apt "$APT_PKG"; then ok "$NAME ya instalado (apt:$APT_PKG)"; return 0; fi ;;
    flatpak) if [[ -n "$FLATPAK_ID" ]] && is_installed_flatpak "$FLATPAK_ID"; then ok "$NAME ya instalado (flatpak:$FLATPAK_ID)"; return 0; fi ;;
    deb)     if [[ -n "$CHECK_CMD" ]] && is_installed_cmd "$CHECK_CMD"; then ok "$NAME ya instalado (.deb / $CHECK_CMD)"; return 0; fi ;;
  esac

  # 2) Detectar otros métodos instalados
  local found_other=false; local to_remove_msg=""
  if [[ "$WANT" != "apt" && -n "$APT_PKG" ]] && is_installed_apt "$APT_PKG"; then found_other=true; to_remove_msg+=" apt:$APT_PKG"; fi
  if [[ "$WANT" != "flatpak" && -n "$FLATPAK_ID" ]] && is_installed_flatpak "$FLATPAK_ID"; then found_other=true; to_remove_msg+=" flatpak:$FLATPAK_ID"; fi
  if [[ "$WANT" != "snap" && -n "$SNAP_PKG" ]] && is_installed_snap "$SNAP_PKG"; then found_other=true; to_remove_msg+=" snap:$SNAP_PKG"; fi

  if $found_other; then
    if prompt_yes_no "Se detectó ${NAME} por otro método (${to_remove_msg}). ¿Deseas desinstalar y cambiar a ${WANT}?"; then
      [[ "$WANT" != "apt"     && -n "$APT_PKG"    ]] && is_installed_apt "$APT_PKG" && remove_apt "$APT_PKG"
      [[ "$WANT" != "flatpak" && -n "$FLATPAK_ID" ]] && is_installed_flatpak "$FLATPAK_ID" && remove_flatpak "$FLATPAK_ID"
      [[ "$WANT" != "snap"    && -n "$SNAP_PKG"   ]] && is_installed_snap "$SNAP_PKG" && remove_snap "$SNAP_PKG"
    else
      warn "Manteniendo instalación existente de ${NAME}. Se omite cambio."
      return 0
    fi
  fi

  # 3) Instalar por el método deseado
  case "$WANT" in
    apt)     run "Instalar $NAME (apt)" apt-get install -yq "$APT_PKG" ;;
    flatpak) run "Instalar $NAME (Flatpak)" flatpak install -y --noninteractive flathub "$FLATPAK_ID" ;;
    deb)
      if [[ -n "$INSTALL_FN" ]]; then "$INSTALL_FN" || error "Fallo instalando $NAME (.deb)"; else error "Falta función de instalación para $NAME (.deb)"; return 1; fi
      ;;
    *) error "Método no soportado: $WANT"; return 1 ;;
  esac
}

# ======================= Instalador Cursor (.deb) =======================
install_cursor_deb() {
  local ARCH_DEB="x64"
  [[ "$(dpkg --print-architecture)" == "arm64" ]] && ARCH_DEB="ARM64"
  local TMP_DEB="/tmp/cursor_latest_${ARCH_DEB}.deb"

  detect_cursor_deb_url() {
    curl -fsSL "https://cursor.com/downloads" | grep -Eo 'https?://[^"]+\.deb' | head -n1
  }

  local DL_URL=""
  if [[ -n "${CURSOR_DEB_URL:-}" ]]; then
    DL_URL="${CURSOR_DEB_URL}"
  else
    info "Detectando URL del .deb más reciente de Cursor…"
    DL_URL="$(detect_cursor_deb_url || true)"
  fi
  [[ -z "$DL_URL" ]] && { error "No se pudo detectar el .deb de Cursor"; return 1; }

  info "Descargando Cursor: ${DL_URL}"
  curl -fL "${DL_URL}" -o "${TMP_DEB}" 2>&1 | tee -a "${LOG_FILE}"

  if apt-get install -yq "${TMP_DEB}" 2>&1 | tee -a "${LOG_FILE}"; then
    ok "Cursor instalado (apt con .deb)"
  else
    warn "apt falló; intentando dpkg + fix-deps"
    dpkg -i "${TMP_DEB}" 2>&1 | tee -a "${LOG_FILE}" || true
    apt-get -f install -yq 2>&1 | tee -a "${LOG_FILE}"
    ok "Cursor instalado (dpkg + fix-deps)"
  fi

  if command -v cursor >/dev/null 2>&1; then ok "Verificación: cursor en PATH"; else warn "cursor no aparece en PATH"; fi
}

# ======================= Inicio =======================
must_root
prep_log
section "Inicio - Log: ${LOG_FILE}"

REAL_USER="${SUDO_USER:-$USER}"
[[ -z "${REAL_USER}" || "${REAL_USER}" == "root" ]] && warn "No se detectó usuario no-root; omitir añadir a grupos."

# ======================= 1. Actualización del sistema =======================
section "Actualizar sistema"
run "apt update" apt-get update -y
run "apt upgrade" apt-get upgrade -yq
run "apt dist-upgrade" apt-get dist-upgrade -yq
run "apt autoremove" apt-get autoremove -yq
run "apt autoclean" apt-get autoclean -yq

# ======================= 2. Paquetes base =======================
section "Instalar paquetes base"
run "Instalar herramientas base" apt-get install -yq --no-install-recommends \
  ca-certificates curl wget gnupg lsb-release software-properties-common nano unzip tar xz-utils \
  flatpak desktop-file-utils

# ======================= 3. Flatpak + Flathub =======================
section "Configurar Flatpak"
if ! flatpak remotes | grep -q flathub; then
  run "Agregar Flathub" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
  ok "Flathub ya estaba configurado"
fi

# ======================= 4. Repos previos necesarios =======================
section "Configurar repo oficial de VS Code"
if command -v code >/dev/null 2>&1; then
  ok "VS Code ya está instalado, se omite configuración de repositorio"
else
  if ! grep -q "packages.microsoft.com/repos/code" /etc/apt/sources.list.d/vscode.list 2>/dev/null; then
    run "Preparar keyring de Microsoft" install -m 0755 -d /etc/apt/keyrings
    run "Descargar GPG de Microsoft" bash -c "curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/ms_vscode.gpg"
    run "Permisos keyring" chmod a+r /etc/apt/keyrings/ms_vscode.gpg
    run "Agregar repo VS Code" bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ms_vscode.gpg] https://packages.microsoft.com/repos/code stable main' > /etc/apt/sources.list.d/vscode.list"
    run "apt update (VS Code)" apt-get update -y
  else
    ok "Repo de VS Code ya presente"
  fi
fi

# ======================= 5. Apps - General =======================
section "Instalar perfil General"
ensure_app "LibreOffice" "apt" "libreoffice" "" "" "" ""
ensure_app "Zoom"        "flatpak" "" "us.zoom.Zoom" "zoom-client" "" ""

# ======================= 6. Apps - Dev =======================
section "Instalar perfil Dev"
# VS Code (apt Microsoft); si existía Flatpak, ofrece migrar
ensure_app "Visual Studio Code" "apt" "code" "com.visualstudio.code" "" "code" ""
# Thunderbird por Flatpak (migrar si apt)
ensure_app "Thunderbird" "flatpak" "thunderbird" "org.mozilla.Thunderbird" "" "thunderbird" ""
# DBeaver CE por Flatpak (migrar si apt)
ensure_app "DBeaver CE" "flatpak" "dbeaver-ce" "io.dbeaver.DBeaverCommunity" "" "dbeaver" ""
# Termius por Flatpak
ensure_app "Termius" "flatpak" "" "com.termius.Termius" "" "termius" ""
# Postman/Insomnia por Flatpak
case "${INSTALL_API_CLIENTS}" in
  postman)  ensure_app "Postman"  "flatpak" "postman"  "com.getpostman.Postman" "" "postman"  "" ;;
  insomnia) ensure_app "Insomnia" "flatpak" "insomnia" "rest.insomnia.Insomnia" "" "insomnia" "" ;;
  both|*)   ensure_app "Postman"  "flatpak" "postman"  "com.getpostman.Postman" "" "postman"  ""
            ensure_app "Insomnia" "flatpak" "insomnia" "rest.insomnia.Insomnia" "" "insomnia" "" ;;
esac
# Zen Browser (Flatpak comunitario)
ensure_app "Zen Browser" "flatpak" "" "io.github.zen_browser.zen" "" "zen" ""
# Cursor .deb
ensure_app "Cursor" "deb" "" "" "" "cursor" "install_cursor_deb"

# ======================= 7. Docker CE (oficial) =======================
section "Docker CE (oficial)"
if ! command -v docker >/dev/null 2>&1; then
  run "Preparar keyring Docker" install -m 0755 -d /etc/apt/keyrings
  run "Descargar GPG Docker" bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
  run "Permisos keyring Docker" chmod a+r /etc/apt/keyrings/docker.gpg
  run "Agregar repo Docker" bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' > /etc/apt/sources.list.d/docker.list"
  run "apt update (Docker)" apt-get update -y
  run "Instalar Docker Engine" apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  ok "Docker ya estaba instalado"
fi
run "Habilitar y arrancar Docker" systemctl enable --now docker
if id -u "${REAL_USER}" >/dev/null 2>&1; then
  if getent group docker >/dev/null 2>&1; then
    run "Agregar ${REAL_USER} al grupo docker" usermod -aG docker "${REAL_USER}"
  else
    run "Crear grupo docker" groupadd docker
    run "Agregar ${REAL_USER} al grupo docker" usermod -aG docker "${REAL_USER}"
  fi
else
  warn "No se pudo añadir a grupo docker (usuario real no detectado)"
fi

# ======================= 8. Limpieza =======================
section "Limpieza final"
run "apt autoremove" apt-get autoremove -yq
run "apt autoclean" apt-get autoclean -yq

# ======================= 9. Resumen =======================
section "Resumen"
echo -e "${C_GRAY}Log detallado: ${LOG_FILE}${C_RESET}"
echo -e "${C_GREEN}Instalación completada.${C_RESET}"
echo -e "Aplicaciones objetivo (métodos):"
echo -e " - LibreOffice (apt)"
echo -e " - Zoom (flatpak)"
echo -e " - VS Code (repo oficial Microsoft, apt)"
echo -e " - Cursor (.deb)"
echo -e " - Zen Browser (flatpak)"
echo -e " - Thunderbird (flatpak)"
echo -e " - DBeaver CE (flatpak)"
echo -e " - Termius (flatpak)"
echo -e " - Postman, Insomnia (flatpak)"
echo -e " - Docker CE + Compose plugin (apt repo oficial)"
echo -e "\n${C_YELLOW}Nota:${C_RESET} para que el grupo 'docker' surta efecto en ${REAL_USER}, se requiere nueva sesión (el reinicio lo aplica)."

# ======================= 10. Reinicio =======================
if ${AUTO_REBOOT}; then
  section "Reinicio en ${REBOOT_SECONDS}s"
  for ((i=${REBOOT_SECONDS}; i>0; i--)); do
    echo -ne "Reiniciando en ${i}s... (Ctrl+C para cancelar) \r"
    sleep 1
  done
  echo -e "\n${C_CYAN}Reiniciando ahora...${C_RESET}"
  log "Reinicio solicitado"
  systemctl reboot || reboot
else
  info "AUTO_REBOOT=false → no se reinicia automáticamente."
fi

