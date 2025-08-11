#!/bin/bash

# ===================================================================================
# Python 应用一体化安装与管理脚本 (最终交互菜单版)
#
# 功能:
#   - 首次运行：自动从GitHub下载、交互式配置并设置环境。
#   - 后续运行：提供功能齐全的交互式菜单管理应用的启停、日志和卸载。
#
# 使用方法:
#   1. 在一个空目录中，运行 bash <(curl -sL https://raw.githubusercontent.com/eoovve/vless/main/install.sh)
#      或手动下载此脚本后运行: bash install.sh
#   2. 根据首次运行的提示完成配置。
#   3. 再次运行 bash install.sh 即可进入管理菜单。
# ===================================================================================

# --- 脚本配置 ---
# 颜色代码
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 目标应用的GitHub Raw URL
APP_URL="https://raw.githubusercontent.com/eooce/python-xray-argo/main/app.py"

# 本地文件名及环境
APP_FILE="app.py"
REQ_FILE="requirements.txt"
VENV_DIR="venv"
PID_FILE="app.pid"
LOG_FILE="app.log"
DEFAULT_CACHE_DIR="./.cache"

# --- 核心功能函数 ---

# 检查系统依赖
check_dependencies() {
    echo -e "${CYAN}:: 正在检查所需工具 (curl, python3, pip)...${NC}"
    local missing=0
    if ! command -v curl &> /dev/null; then echo -e "${RED}错误: 未找到 'curl'。${NC}"; missing=1; fi
    if ! command -v python3 &> /dev/null; then echo -e "${RED}错误: 未找到 'python3'。${NC}"; missing=1; fi
    if ! command -v pip3 &> /dev/null; then echo -e "${RED}错误: 未找到 'pip3'。${NC}"; missing=1; fi
    [ "$missing" -eq 1 ] && echo -e "${RED}请先安装以上缺失的工具。${NC}" && exit 1
    echo -e "${GREEN}✓ 依赖检查通过。${NC}"
}

# 下载 app.py
download_app() {
    echo -e "${CYAN}:: 正在从GitHub下载最新的 ${APP_FILE}...${NC}"
    if curl -o "$APP_FILE" -L "$APP_URL"; then
        echo -e "${GREEN}✓ ${APP_FILE} 下载成功。${NC}"
    else
        echo -e "${RED}✗ ${APP_FILE} 下载失败！请检查网络或URL: ${APP_URL}${NC}"
        exit 1
    fi
}

# 配置 app.py
configure_app() {
    echo -e "${CYAN}:: 启动应用配置向导...${NC}"
    echo "接下来，请输入您的配置信息。直接按[回车]将保留文件中的当前值。"
    
    cp "$APP_FILE" "${APP_FILE}.bak"
    echo "已创建原始文件备份: ${APP_FILE}.bak"
    echo

    declare -A CONFIG_PROMPTS
    CONFIG_PROMPTS=(
        ["UUID"]="核心服务的UUID"
        ["ARGO_DOMAIN"]="(可选) 您的Argo固定域名, 留空则使用临时域名"
        ["ARGO_AUTH"]="(可选) 您的Argo密钥(Token或JSON), 留空则使用临时隧道"
        ["ARGO_PORT"]="Argo隧道的内部端口"
        ["CFIP"]="(可选) 优选IP或域名，用于加速"
        ["CFPORT"]="优选IP的端口"
        ["NAME"]="节点名称前缀"
        ["PORT"]="HTTP服务端口"
        ["SUB_PATH"]="订阅路径"
        ["FILE_PATH"]="运行时目录, 一般无需修改"
    )

    for key in "${!CONFIG_PROMPTS[@]}"; do
        desc=${CONFIG_PROMPTS[$key]}
        current_val=$(grep "^${key} = " "$APP_FILE" | cut -d '=' -f 2- | xargs | tr -d "'\"")
        read -p "$(echo -e ${GREEN}"-> 请输入 ${key} ${NC}(${desc}) [${current_val}]: ")" user_input
        if [ -n "$user_input" ]; then
            if [[ "$key" == "PORT" || "$key" == "ARGO_PORT" || "$key" == "CFPORT" ]]; then
                sed -i "s/^\(${key} = \).*/\1${user_input}/" "$APP_FILE"
            else
                escaped_input=$(echo "$user_input" | sed "s/'/\\\'/g")
                sed -i "s/^\(${key} = \).*/\1'${escaped_input}'/" "$APP_FILE"
            fi
            echo -e "   ${YELLOW}已将 ${key} 更新为: ${user_input}${NC}"
        fi
    done
}

# 设置 Python 虚拟环境
setup_venv() {
    echo -e "${CYAN}:: 正在设置Python运行环境...${NC}"
    if [ ! -d "$VENV_DIR" ]; then
        if [ ! -f "$REQ_FILE" ]; then echo "requests" > "$REQ_FILE"; fi
        python3 -m venv "$VENV_DIR"
        source "${VENV_DIR}/bin/activate"
        pip install -r "$REQ_FILE"
        deactivate
        echo -e "${GREEN}✓ Python虚拟环境设置完成。${NC}"
    else
        echo -e "${YELLOW}虚拟环境已存在，跳过设置。${NC}"
    fi
}

# 启动应用
start_app() {
    if [ -f "$PID_FILE" ]; then echo -e "${YELLOW}应用已在运行中。${NC}"; return; fi
    echo -e "${CYAN}:: 正在启动应用...${NC}"
    source "${VENV_DIR}/bin/activate"
    nohup python3 "$APP_FILE" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    deactivate
    sleep 2
    if [ -f "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" > /dev/null; then
        echo -e "${GREEN}✓ 应用启动成功 (进程ID: $(cat $PID_FILE))。${NC}"
    else
        echo -e "${RED}✗ 应用启动失败。请通过菜单查看日志。${NC}"
        rm -f "$PID_FILE"
    fi
}

# 停止应用
stop_app() {
    echo -e "${CYAN}:: 正在停止所有相关进程...${NC}"
    local stopped_count=0
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null; then kill -9 "$pid"; fi
        rm -f "$PID_FILE"
        echo "   - 主脚本 (进程ID: $pid) 已停止。"
        stopped_count=$((stopped_count + 1))
    fi
    for proc_name in web bot npm php; do
        pids_to_kill=$(ps -ef | grep "[${proc_name:0:1}]${proc_name:1}" | awk '{print $2}')
        if [ -n "$pids_to_kill" ]; then
            for pid in $pids_to_kill; do
                kill -9 "$pid"
                echo "   - 衍生进程 '$proc_name' (进程ID: $pid) 已停止。"
                stopped_count=$((stopped_count + 1))
            done
        fi
    done
    if [ "$stopped_count" -eq 0 ]; then echo -e "${YELLOW}未发现正在运行的相关进程。${NC}"; else echo -e "${GREEN}✓ 所有相关进程均已停止。${NC}"; fi
}

# 查看日志
view_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}日志文件不存在。请先启动应用。${NC}"
    else
        clear
        echo "正在显示实时日志... 按 Ctrl+C 组合键可随时退出。"
        tail -f "$LOG_FILE"
    fi
}

# 卸载
uninstall_app() {
    clear
    echo -e "${RED}警告: 此操作将停止应用并永久删除所有相关文件！${NC}"
    read -p "您确定要继续吗? [y/N]: " choice
    if [[ "$choice" != "y" ]] && [[ "$choice" != "Y" ]]; then
        echo "操作已取消。"
    else
        echo -e "${CYAN}:: 正在执行彻底清理...${NC}"
        stop_app > /dev/null 2>&1
        rm -rf "$VENV_DIR" "$DEFAULT_CACHE_DIR" "$APP_FILE" "${APP_FILE}.bak" "$REQ_FILE" "$LOG_FILE" "$PID_FILE"
        echo -e "${GREEN}✓ 清理完成。${NC}"
        echo "脚本将退出，您可以安全地删除此脚本文件。"
        exit 0
    fi
}

# 首次安装流程
run_first_time_install() {
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    欢迎使用一体化安装程序    ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    check_dependencies
    download_app
    configure_app
    setup_venv
    echo -e "\n${GREEN}====================== 安装配置完成 ======================${NC}"
    echo -e "${GREEN}✓ 所有准备工作已就绪!${NC}"
    echo
    echo "现在，请再次运行此脚本以进入管理菜单:"
    echo -e "${YELLOW}    bash install.sh${NC}"
    echo "=========================================================="
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=======================================${NC}"
        echo -e "${CYAN}         应用管理菜单      ${NC}"
        echo -e "${CYAN}=======================================${NC}"
        echo -e " ${GREEN}1.${NC} ${CYAN}启动${NC} 应用服务"
        echo -e " ${GREEN}2.${NC} ${RED}停止${NC} 应用服务"
        echo -e " ${GREEN}3.${NC} 重启应用服务"
        echo -e " ${GREEN}4.${NC} 查看实时日志"
        echo -e " ${GREEN}5.${NC} 重新配置应用"
        echo -e " ${GREEN}6.${NC} ${RED}卸载应用${NC}"
        echo -e " ${YELLOW}7.${NC} 退出脚本"
        echo
        
        if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null; then
            echo -e "当前状态: ${GREEN}运行中 (进程ID: $(cat $PID_FILE))${NC}"
        else
            echo -e "当前状态: ${RED}已停止${NC}"
        fi

        read -p "请输入您的选择 [1-7]: " choice

        case $choice in
            1) start_app; read -p "按 [回车] 返回主菜单。" ;;
            2) stop_app; read -p "按 [回车] 返回主菜单。" ;;
            3) stop_app; sleep 1; start_app; read -p "按 [回车] 返回主菜单。" ;;
            4) view_logs ;;
            5) configure_app; echo -e "\n${GREEN}✓ 重新配置完成。如果应用正在运行，请重启以生效。${NC}"; read -p "按 [回车] 返回主菜单。" ;;
            6) uninstall_app; ;;
            7) exit 0 ;;
            *) echo -e "${RED}无效输入，请重新选择。${NC}"; sleep 1 ;;
        esac
    done
}

# --- 脚本主入口 ---
# 通过检查 app.py 是否存在来判断是首次运行还是后续管理
if [ ! -f "$APP_FILE" ]; then
    run_first_time_install
else
    main_menu
fi    deactivate
    echo -e "${GREEN}✓ Python 环境设置完成。${NC}"
}

# 3. 用于配置 .env 文件的交互式向导
configure_env() {
    echo -e "${CYAN}:: 启动环境变量配置向导...${NC}"
    echo "提示：直接按 [回车] 将使用括号 [] 中显示的默认值。"

    declare -A VARS
    VARS=(
        ["UPLOAD_URL"]="'' # (可选) 节点或订阅的上传地址"
        ["PROJECT_URL"]="'' # (可选) 用于自动保活或上传订阅的项目URL"
        ["AUTO_ACCESS"]="'false' # (可选) 是否开启自动保活 (true/false)"
        ["FILE_PATH"]="'./.cache' # (可选) 运行时缓存目录"
        ["SUB_PATH"]="'sub' # (可选) 订阅路径的访问令牌"
        ["UUID"]="'20e6e496-cf19-45c8-b883-14f5e11cd9f1' # (可选) 你的 VLESS/VMess UUID"
        ["NEZHA_SERVER"]="'' # (可选) 哪吒面板服务器地址 (例如: domain.com:8008)"
        ["NEZHA_PORT"]="'' # (可选) 哪吒v0的Agent端口 (v1版请留空)"
        ["NEZHA_KEY"]="'' # (可选) 哪吒面板的密钥或Secret"
        ["ARGO_DOMAIN"]="'' # (可选) Argo隧道的固定域名"
        ["ARGO_AUTH"]="'' # (可选) Argo隧道的JSON或Token"
        ["ARGO_PORT"]="'8001' # (可选) Argo隧道的内部端口"
        ["CFIP"]="'www.visa.com.tw' # (可选) 优选的Cloudflare IP或域名"
        ["CFPORT"]="'443' # (可选) 优选的Cloudflare端口"
        ["NAME"]="'Vls' # (可选) 节点名称的前缀"
        ["CHAT_ID"]="'' # (可选) 用于推送通知的Telegram Chat ID"
        ["BOT_TOKEN"]="'' # (可选) 用于推送通知的Telegram Bot Token"
        ["PORT"]="'3000' # (可选) HTTP服务的监听端口"
    )

    > "$ENV_FILE"

    for key in "${!VARS[@]}"; do
        value_desc=${VARS[$key]}
        default_val=$(echo "$value_desc" | cut -d'#' -f1 | tr -d " '")
        desc=$(echo "$value_desc" | cut -d'#' -f2-)

        read -p "$(echo -e ${GREEN}"-> 请输入 ${key} 的值 ${NC}(${desc}) [${default_val}]: ")" user_input
        final_val=${user_input:-$default_val}
        echo "${key}=\"${final_val}\"" >> "$ENV_FILE"
    done

    echo -e "${GREEN}✓ 配置已成功保存至 ${ENV_FILE}。${NC}"
}

# 4. 启动应用程序及其所有后台进程
#    $1: 运行模式 ("auto" 或 "manual")
start_app() {
    local mode=$1
    if [ -f "$PID_FILE" ]; then
        echo -e "${YELLOW}应用似乎已在运行 (进程ID: $(cat $PID_FILE))。${NC}"
        if [ "$mode" == "manual" ]; then read -p "按 [回车] 返回主菜单。" ; fi
        return
    fi

    echo -e "${CYAN}:: 正在启动应用...${NC}"
    # shellcheck source=/dev/null
    source "${VENV_DIR}/bin/activate"
    
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    fi

    nohup python3 "$APP_FILE" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    deactivate
    
    sleep 2
    if [ -f "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" > /dev/null; then
        echo -e "${GREEN}✓ 应用启动成功 (进程ID: $(cat $PID_FILE))。${NC}"
        echo "   日志文件位于: ${LOG_FILE}"
    else
        echo -e "${RED}错误: 应用启动失败。请检查 ${LOG_FILE} 文件以获取详细信息。${NC}"
        rm -f "$PID_FILE"
    fi

    if [ "$mode" == "manual" ]; then read -p "按 [回车] 返回主菜单。" ; fi
}

# 5. 停止主应用及其衍生的所有后台进程 (兼容性版本)
stop_app() {
    echo -e "${CYAN}:: 正在停止所有相关进程...${NC}"
    local stopped_count=0

    # 停止主Python脚本
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null; then
            kill -9 "$pid"
            echo "   - 主脚本 (进程ID: $pid) 已停止。"
            stopped_count=$((stopped_count + 1))
        fi
        rm -f "$PID_FILE"
    fi

    # 终止衍生的进程
    for proc_name in web bot npm php; do
        # 使用 ps, grep, awk 安全地查找并停止进程
        # grep "[$p]" 是一个技巧，可以防止 grep 命令找到它自己
        pids_to_kill=$(ps -ef | grep "[${proc_name:0:1}]${proc_name:1}" | awk '{print $2}')
        if [ -n "$pids_to_kill" ]; then
            for pid in $pids_to_kill; do
                kill -9 "$pid"
                echo "   - 衍生进程 '$proc_name' (进程ID: $pid) 已停止。"
                stopped_count=$((stopped_count + 1))
            done
        fi
    done
    
    if [ "$stopped_count" -eq 0 ]; then
        echo -e "${YELLOW}未发现正在运行的相关进程。${NC}"
    else
        echo -e "${GREEN}✓ 所有相关进程均已停止。${NC}"
    fi
    read -p "按 [回车] 返回主菜单。"
}


# 6. 清理所有生成的文件和目录
cleanup() {
    echo -e "${RED}警告: 此操作将停止所有进程并永久删除以下内容：${NC}"
    echo "  - Python虚拟环境 ('$VENV_DIR')"
    echo "  - 运行时缓存目录 ('$DEFAULT_CACHE_DIR')"
    echo "  - 所有日志和配置文件 (.env, .pid, .log, requirements.txt)"
    read -p "您确定要继续吗? [y/N]: " choice
    if [[ "$choice" != "y" ]] && [[ "$choice" != "Y" ]]; then
        echo "清理操作已取消。"
        read -p "按 [回车] 返回。"
        return
    fi
    
    echo -e "${CYAN}:: 正在执行彻底清理...${NC}"
    # 首先停止所有进程
    stop_app > /dev/null 2>&1

    # 删除文件和目录
    rm -rf "$VENV_DIR" "$DEFAULT_CACHE_DIR" "$ENV_FILE" "$PID_FILE" "$LOG_FILE" "$REQ_FILE"
    echo -e "${GREEN}✓ 清理完成。${NC}"
    read -p "按 [回车] 退出脚本。"
    exit 0
}


# --- 主菜单 (用于后续运行) ---
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=======================================${NC}"
        echo -e "${CYAN}         应用管理菜单      ${NC}"
        echo -e "${CYAN}=======================================${NC}"
        echo -e " ${GREEN}1.${NC} ${CYAN}启动${NC} 应用服务"
        echo -e " ${GREEN}2.${NC} ${RED}停止${NC} 应用服务"
        echo -e " ${GREEN}3.${NC} 重新配置环境变量"
        echo -e " ${GREEN}4.${NC} 查看实时日志 (按 Ctrl+C 退出)"
        echo -e " ${GREEN}5.${NC} ${RED}卸载并清理所有文件${NC}"
        echo -e " ${YELLOW}6.${NC} 退出脚本"
        echo
        
        if [ -f "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" > /dev/null; then
            echo -e "当前状态: ${GREEN}运行中 (进程ID: $(cat $PID_FILE))${NC}"
        else
            echo -e "当前状态: ${RED}已停止${NC}"
        fi

        read -p "请输入您的选择 [1-6]: " choice

        case $choice in
            1) start_app "manual" ;;
            2) stop_app ;;
            3) configure_env; read -p "配置完成，按[回车]返回" ;;
            4) clear; echo "正在显示实时日志... 按 Ctrl+C 组合键可随时退出。"; tail -f "$LOG_FILE" ;;
            5) cleanup ;;
            6) exit 0 ;;
            *) echo -e "${RED}无效输入，请重新选择。${NC}"; sleep 1 ;;
        esac
    done
}


# --- 脚本主逻辑 ---
# 通过检查虚拟环境是否存在来判断是否为首次运行
if [ ! -d "$VENV_DIR" ]; then
    # --- 首次运行的自动化流程 ---
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    欢迎使用! 检测到首次运行，将开始全自动安装...    ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    
    # 步骤 1: 检查环境
    check_dependencies
    echo
    # 步骤 2: 创建Python环境并安装依赖
    setup_environment
    echo
    # 步骤 3: 交互式配置
    configure_env
    echo
    # 步骤 4: 自动启动应用
    echo -e "${CYAN}--- 正在自动启动应用 ---${NC}"
    start_app "auto" # 使用 "auto" 模式，不暂停
    
    echo -e "\n${GREEN}====================== 首次启动完成 ======================${NC}"
    echo -e "${GREEN}✓ 应用已在后台开始运行！${NC}"
    echo -e "它现在会自动下载所需组件并生成订阅链接，这可能需要1-2分钟。"
    echo
    echo -e "您可以立即重新运行此脚本 (${YELLOW}./manage.sh${NC})，然后:"
    echo -e "  - 选择“${CYAN}查看实时日志${NC}”来监控进度。"
    echo -e "  - 当日志中出现订阅链接时，代表服务已就绪。"
    echo -e "  - 使用菜单中的其他选项来管理您的应用（如停止或卸载）。"
    echo -e "=========================================================="

else
    # --- 后续运行，直接显示管理菜单 ---
    main_menu
fi    source "${VENV_DIR}/bin/activate"
    pip install -r "$REQ_FILE"
    deactivate
    echo -e "${GREEN}✓ Python 环境设置完成。${NC}"
}

# 3. 用于配置 .env 文件的交互式向导
configure_env() {
    echo -e "${CYAN}:: 启动环境变量配置向导...${NC}"
    echo "提示：直接按 [回车] 将使用括号 [] 中显示的默认值。"

    # 使用关联数组简化变量管理
    declare -A VARS
    VARS=(
        ["UPLOAD_URL"]="'' # (可选) 节点或订阅的上传地址"
        ["PROJECT_URL"]="'' # (可选) 用于自动保活或上传订阅的项目URL"
        ["AUTO_ACCESS"]="'false' # (可选) 是否开启自动保活 (true/false)"
        ["FILE_PATH"]="'./.cache' # (可选) 运行时缓存目录"
        ["SUB_PATH"]="'sub' # (可选) 订阅路径的访问令牌"
        ["UUID"]="'20e6e496-cf19-45c8-b883-14f5e11cd9f1' # (可选) 你的 VLESS/VMess UUID"
        ["NEZHA_SERVER"]="'' # (可选) 哪吒面板服务器地址 (例如: domain.com:8008)"
        ["NEZHA_PORT"]="'' # (可选) 哪吒v0的Agent端口 (v1版请留空)"
        ["NEZHA_KEY"]="'' # (可选) 哪吒面板的密钥或Secret"
        ["ARGO_DOMAIN"]="'' # (可选) Argo隧道的固定域名"
        ["ARGO_AUTH"]="'' # (可选) Argo隧道的JSON或Token"
        ["ARGO_PORT"]="'8001' # (可选) Argo隧道的内部端口"
        ["CFIP"]="'www.visa.com.tw' # (可选) 优选的Cloudflare IP或域名"
        ["CFPORT"]="'443' # (可选) 优选的Cloudflare端口"
        ["NAME"]="'Vls' # (可选) 节点名称的前缀"
        ["CHAT_ID"]="'' # (可选) 用于推送通知的Telegram Chat ID"
        ["BOT_TOKEN"]="'' # (可选) 用于推送通知的Telegram Bot Token"
        ["PORT"]="'3000' # (可选) HTTP服务的监听端口"
    )

    # 清空现有的 .env 文件
    > "$ENV_FILE"

    for key in "${!VARS[@]}"; do
        value_desc=${VARS[$key]}
        default_val=$(echo "$value_desc" | cut -d'#' -f1 | tr -d " '")
        desc=$(echo "$value_desc" | cut -d'#' -f2-)

        read -p "$(echo -e ${GREEN}"-> 请输入 ${key} 的值 ${NC}(${desc}) [${default_val}]: ")" user_input
        final_val=${user_input:-$default_val}
        echo "${key}=\"${final_val}\"" >> "$ENV_FILE"
    done

    echo -e "${GREEN}✓ 配置已成功保存至 ${ENV_FILE}。${NC}"
}

# 4. 启动应用程序及其所有后台进程
#    $1: 运行模式 ("auto" 或 "manual")
start_app() {
    local mode=$1
    if [ -f "$PID_FILE" ]; then
        echo -e "${YELLOW}应用似乎已在运行 (进程ID: $(cat $PID_FILE))。${NC}"
        if [ "$mode" == "manual" ]; then read -p "按 [回车] 返回主菜单。" ; fi
        return
    fi

    echo -e "${CYAN}:: 正在启动应用...${NC}"
    # shellcheck source=/dev/null
    source "${VENV_DIR}/bin/activate"
    
    # 从 .env 文件加载环境变量
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    fi

    # 在后台运行Python脚本, 并将输出记录到日志文件
    nohup python3 "$APP_FILE" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    deactivate
    
    sleep 2 # 等待片刻以确保进程已启动
    if [ -f "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" > /dev/null; then
        echo -e "${GREEN}✓ 应用启动成功 (进程ID: $(cat $PID_FILE))。${NC}"
        echo "   日志文件位于: ${LOG_FILE}"
    else
        echo -e "${RED}错误: 应用启动失败。请检查 ${LOG_FILE} 文件以获取详细信息。${NC}"
        rm -f "$PID_FILE"
    fi

    if [ "$mode" == "manual" ]; then read -p "按 [回车] 返回主菜单。" ; fi
}

# 5. 停止主应用及其衍生的所有后台进程
stop_app() {
    echo -e "${CYAN}:: 正在停止所有相关进程...${NC}"
    local stopped=0

    # 停止主Python脚本
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null; then
            kill -9 "$pid"
            echo "   - 主脚本 (进程ID: $pid) 已停止。"
            stopped=1
        fi
        rm -f "$PID_FILE"
    fi

    # 根据进程名称终止衍生的进程
    # 技巧: 使用[p]roc来避免pkill命令匹配到自身
    for proc in web bot npm php; do
        if pgrep -f "[$proc]" > /dev/null; then
            pkill -9 -f "[$proc]"
            echo "   - 衍生进程 '$proc' 已停止。"
            stopped=1
        fi
    done
    
    if [ "$stopped" -eq 0 ]; then
        echo -e "${YELLOW}未发现正在运行的相关进程。${NC}"
    else
        echo -e "${GREEN}✓ 所有相关进程均已停止。${NC}"
    fi
    read -p "按 [回车] 返回主菜单。"
}

# 6. 清理所有生成的文件和目录
cleanup() {
    echo -e "${RED}警告: 此操作将停止所有进程并永久删除以下内容：${NC}"
    echo "  - Python虚拟环境 ('$VENV_DIR')"
    echo "  - 运行时缓存目录 ('$DEFAULT_CACHE_DIR')"
    echo "  - 所有日志和配置文件 (.env, .pid, .log, requirements.txt)"
    read -p "您确定要继续吗? [y/N]: " choice
    if [[ "$choice" != "y" ]] && [[ "$choice" != "Y" ]]; then
        echo "清理操作已取消。"
        read -p "按 [回车] 返回。"
        return
    fi
    
    echo -e "${CYAN}:: 正在执行彻底清理...${NC}"
    # 首先停止所有进程
    stop_app > /dev/null 2>&1

    # 删除文件和目录
    rm -rf "$VENV_DIR" "$DEFAULT_CACHE_DIR" "$ENV_FILE" "$PID_FILE" "$LOG_FILE" "$REQ_FILE"
    echo -e "${GREEN}✓ 清理完成。${NC}"
    read -p "按 [回车] 退出脚本。"
    exit 0
}


# --- 主菜单 (用于后续运行) ---
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=======================================${NC}"
        echo -e "${CYAN}         应用管理菜单      ${NC}"
        echo -e "${CYAN}=======================================${NC}"
        echo -e " ${GREEN}1.${NC} ${CYAN}启动${NC} 应用服务"
        echo -e " ${GREEN}2.${NC} ${RED}停止${NC} 应用服务"
        echo -e " ${GREEN}3.${NC} 重新配置环境变量"
        echo -e " ${GREEN}4.${NC} 查看实时日志 (按 Ctrl+C 退出)"
        echo -e " ${GREEN}5.${NC} ${RED}卸载并清理所有文件${NC}"
        echo -e " ${YELLOW}6.${NC} 退出脚本"
        echo
        
        if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE)" > /dev/null; then
            echo -e "当前状态: ${GREEN}运行中 (进程ID: $(cat $PID_FILE))${NC}"
        else
            echo -e "当前状态: ${RED}已停止${NC}"
        fi

        read -p "请输入您的选择 [1-6]: " choice

        case $choice in
            1) start_app "manual" ;;
            2) stop_app ;;
            3) configure_env; read -p "配置完成，按[回车]返回" ;;
            4) clear; echo "正在显示实时日志... 按 Ctrl+C 组合键可随时退出。"; tail -f "$LOG_FILE" ;;
            5) cleanup ;;
            6) exit 0 ;;
            *) echo -e "${RED}无效输入，请重新选择。${NC}"; sleep 1 ;;
        esac
    done
}


# --- 脚本主逻辑 ---
# 通过检查虚拟环境是否存在来判断是否为首次运行
if [ ! -d "$VENV_DIR" ]; then
    # --- 首次运行的自动化流程 ---
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    欢迎使用! 检测到首次运行，将开始全自动安装...    ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    
    # 步骤 1: 检查环境
    check_dependencies
    echo
    # 步骤 2: 创建Python环境并安装依赖
    setup_environment
    echo
    # 步骤 3: 交互式配置
    configure_env
    echo
    # 步骤 4: 自动启动应用
    echo -e "${CYAN}--- 正在自动启动应用 ---${NC}"
    start_app "auto" # 使用 "auto" 模式，不暂停
    
    echo -e "\n${GREEN}====================== 首次启动完成 ======================${NC}"
    echo -e "${GREEN}✓ 应用已在后台开始运行！${NC}"
    echo -e "它现在会自动下载所需组件并生成订阅链接，这可能需要1-2分钟。"
    echo
    echo -e "您可以立即重新运行此脚本 (${YELLOW}./test.sh${NC})，然后:"
    echo -e "  - 选择“${CYAN}查看实时日志${NC}”来监控进度。"
    echo -e "  - 当日志中出现订阅链接时，代表服务已就绪。"
    echo -e "  - 使用菜单中的其他选项来管理您的应用（如停止或卸载）。"
    echo -e "=========================================================="

else
    # --- 后续运行，直接显示管理菜单 ---
    main_menu
fi}

# 3. 用于配置 .env 文件的交互式向导
configure_env() {
    echo -e "${CYAN}:: 启动环境变量配置向导...${NC}"
    echo "提示：直接按 [回车] 将使用括号 [] 中显示的默认值。"

    # 使用关联数组简化变量管理
    declare -A VARS
    VARS=(
        ["UPLOAD_URL"]="'' # (可选) 节点或订阅的上传地址"
        ["PROJECT_URL"]="'' # (可选) 用于自动保活或上传订阅的项目URL"
        ["AUTO_ACCESS"]="'false' # (可选) 是否开启自动保活 (true/false)"
        ["FILE_PATH"]="'./.cache' # (可选) 运行时缓存目录"
        ["SUB_PATH"]="'sub' # (可选) 订阅路径的访问令牌"
        ["UUID"]="'20e6e496-cf19-45c8-b883-14f5e11cd9f1' # (可选) 你的 VLESS/VMess UUID"
        ["NEZHA_SERVER"]="'' # (可选) 哪吒面板服务器地址 (例如: domain.com:8008)"
        ["NEZHA_PORT"]="'' # (可选) 哪吒v0的Agent端口 (v1版请留空)"
        ["NEZHA_KEY"]="'' # (可选) 哪吒面板的密钥或Secret"
        ["ARGO_DOMAIN"]="'' # (可选) Argo隧道的固定域名"
        ["ARGO_AUTH"]="'' # (可选) Argo隧道的JSON或Token"
        ["ARGO_PORT"]="'8001' # (可选) Argo隧道的内部端口"
        ["CFIP"]="'www.visa.com.tw' # (可选) 优选的Cloudflare IP或域名"
        ["CFPORT"]="'443' # (可选) 优选的Cloudflare端口"
        ["NAME"]="'Vls' # (可选) 节点名称的前缀"
        ["CHAT_ID"]="'' # (可选) 用于推送通知的Telegram Chat ID"
        ["BOT_TOKEN"]="'' # (可选) 用于推送通知的Telegram Bot Token"
        ["PORT"]="'3000' # (可选) HTTP服务的监听端口"
    )

    # 清空现有的 .env 文件
    > "$ENV_FILE"

    for key in "${!VARS[@]}"; do
        value_desc=${VARS[$key]}
        default_val=$(echo "$value_desc" | cut -d'#' -f1 | tr -d " '")
        desc=$(echo "$value_desc" | cut -d'#' -f2-)

        read -p "$(echo -e ${GREEN}"-> 请输入 ${key} 的值 ${NC}(${desc}) [${default_val}]: ")" user_input
        final_val=${user_input:-$default_val}
        echo "${key}=\"${final_val}\"" >> "$ENV_FILE"
    done

    echo -e "${GREEN}✓ 配置已成功保存至 ${ENV_FILE}。${NC}"
}

# 4. 启动应用程序及其所有后台进程
#    $1: 运行模式 ("auto" 或 "manual")
start_app() {
    local mode=$1
    if [ -f "$PID_FILE" ]; then
        echo -e "${YELLOW}应用似乎已在运行 (进程ID: $(cat $PID_FILE))。${NC}"
        if [ "$mode" == "manual" ]; then read -p "按 [回车] 返回主菜单。" ; fi
        return
    fi

    echo -e "${CYAN}:: 正在启动应用...${NC}"
    # shellcheck source=/dev/null
    source "${VENV_DIR}/bin/activate"
    
    # 从 .env 文件加载环境变量
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    fi

    # 在后台运行Python脚本, 并将输出记录到日志文件
    nohup python3 "$APP_FILE" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    deactivate
    
    sleep 2 # 等待片刻以确保进程已启动
    if [ -f "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" > /dev/null; then
        echo -e "${GREEN}✓ 应用启动成功 (进程ID: $(cat $PID_FILE))。${NC}"
        echo "   日志文件位于: ${LOG_FILE}"
    else
        echo -e "${RED}错误: 应用启动失败。请检查 ${LOG_FILE} 文件以获取详细信息。${NC}"
        rm -f "$PID_FILE"
    fi

    if [ "$mode" == "manual" ]; then read -p "按 [回车] 返回主菜单。" ; fi
}

# 5. 停止主应用及其衍生的所有后台进程
stop_app() {
    echo -e "${CYAN}:: 正在停止所有相关进程...${NC}"
    local stopped=0

    # 停止主Python脚本
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null; then
            kill -9 "$pid"
            echo "   - 主脚本 (进程ID: $pid) 已停止。"
            stopped=1
        fi
        rm -f "$PID_FILE"
    fi

    # 根据进程名称终止衍生的进程
    # 技巧: 使用[p]roc来避免pkill命令匹配到自身
    for proc in web bot npm php; do
        if pgrep -f "[$proc]" > /dev/null; then
            pkill -9 -f "[$proc]"
            echo "   - 衍生进程 '$proc' 已停止。"
            stopped=1
        fi
    done
    
    if [ "$stopped" -eq 0 ]; then
        echo -e "${YELLOW}未发现正在运行的相关进程。${NC}"
    else
        echo -e "${GREEN}✓ 所有相关进程均已停止。${NC}"
    fi
    read -p "按 [回车] 返回主菜单。"
}

# 6. 清理所有生成的文件和目录
cleanup() {
    echo -e "${RED}警告: 此操作将停止所有进程并永久删除以下内容：${NC}"
    echo "  - Python虚拟环境 ('$VENV_DIR')"
    echo "  - 运行时缓存目录 ('$DEFAULT_CACHE_DIR')"
    echo "  - 所有日志和配置文件 (.env, .pid, .log, requirements.txt)"
    read -p "您确定要继续吗? [y/N]: " choice
    if [[ "$choice" != "y" ]] && [[ "$choice" != "Y" ]]; then
        echo "清理操作已取消。"
        read -p "按 [回车] 返回。"
        return
    fi
    
    echo -e "${CYAN}:: 正在执行彻底清理...${NC}"
    # 首先停止所有进程
    stop_app > /dev/null 2>&1

    # 删除文件和目录
    rm -rf "$VENV_DIR" "$DEFAULT_CACHE_DIR" "$ENV_FILE" "$PID_FILE" "$LOG_FILE" "$REQ_FILE"
    echo -e "${GREEN}✓ 清理完成。${NC}"
    read -p "按 [回车] 退出脚本。"
    exit 0
}


# --- 主菜单 (用于后续运行) ---
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=======================================${NC}"
        echo -e "${CYAN}         应用管理菜单      ${NC}"
        echo -e "${CYAN}=======================================${NC}"
        echo -e " ${GREEN}1.${NC} ${CYAN}启动${NC} 应用服务"
        echo -e " ${GREEN}2.${NC} ${RED}停止${NC} 应用服务"
        echo -e " ${GREEN}3.${NC} 重新配置环境变量"
        echo -e " ${GREEN}4.${NC} 查看实时日志 (按 Ctrl+C 退出)"
        echo -e " ${GREEN}5.${NC} ${RED}卸载并清理所有文件${NC}"
        echo -e " ${YELLOW}6.${NC} 退出脚本"
        echo
        
        if [ -f "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" > /dev/null; then
            echo -e "当前状态: ${GREEN}运行中 (进程ID: $(cat $PID_FILE))${NC}"
        else
            echo -e "当前状态: ${RED}已停止${NC}"
        fi

        read -p "请输入您的选择 [1-6]: " choice

        case $choice in
            1) start_app "manual" ;;
            2) stop_app ;;
            3) configure_env; read -p "配置完成，按[回车]返回" ;;
            4) clear; echo "正在显示实时日志... 按 Ctrl+C 组合键可随时退出。"; tail -f "$LOG_FILE" ;;
            5) cleanup ;;
            6) exit 0 ;;
            *) echo -e "${RED}无效输入，请重新选择。${NC}"; sleep 1 ;;
        esac
    done
}


# --- 脚本主逻辑 ---
# 通过检查虚拟环境是否存在来判断是否为首次运行
if [ ! -d "$VENV_DIR" ]; then
    # --- 首次运行的自动化流程 ---
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    欢迎使用! 检测到首次运行，将开始全自动安装...    ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    
    # 步骤 1: 检查环境
    check_dependencies
    echo
    # 步骤 2: 创建Python环境并安装依赖
    setup_environment
    echo
    # 步骤 3: 交互式配置
    configure_env
    echo
    # 步骤 4: 自动启动应用
    echo -e "${CYAN}--- 正在自动启动应用 ---${NC}"
    start_app "auto" # 使用 "auto" 模式，不暂停
    
    echo -e "\n${GREEN}====================== 首次启动完成 ======================${NC}"
    echo -e "${GREEN}✓ 应用已在后台开始运行！${NC}"
    echo -e "它现在会自动下载所需组件并生成订阅链接，这可能需要1-2分钟。"
    echo
    echo -e "您可以立即重新运行此脚本 (${YELLOW}./manage.sh${NC})，然后:"
    echo -e "  - 选择“${CYAN}查看实时日志${NC}”来监控进度。"
    echo -e "  - 当日志中出现订阅链接时，代表服务已就绪。"
    echo -e "  - 使用菜单中的其他选项来管理您的应用（如停止或卸载）。"
    echo -e "=========================================================="

else
    # --- 后续运行，直接显示管理菜单 ---
    main_menu
fi    local missing_deps=0
    if ! command -v git &> /dev/null; then
        echo -e "${RED}错误: 未找到 'git'。请先安装 Git。${NC}"; missing_deps=1; fi
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}错误: 未找到 'python3'。请先安装 Python 3。${NC}"; missing_deps=1; fi
    if ! python3 -m pip --version &> /dev/null; then
        echo -e "${RED}错误: 未找到 'pip' for Python 3。请确保已安装 pip。${NC}"; missing_deps=1; fi

    if [ "$missing_deps" -eq 1 ]; then
        echo -e "${RED}依赖检查失败，请安装所需软件后重试。${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ 依赖检查通过。${NC}"
}

# 下载项目并安装依赖
setup_project() {
    echo -e "${CYAN}:: 正在从 GitHub 下载项目...${NC}"
    git clone "$REPO_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败！请检查网络或 URL 是否正确。${NC}"; exit 1; fi

    echo -e "${CYAN}:: 正在安装依赖 (requirements.txt)...${NC}"
    python3 -m pip install -r "${REPO_DIR}/requirements.txt"
    if [ $? -ne 0 ]; then
        echo -e "${RED}依赖安装失败！${NC}"; exit 1; fi
    echo -e "${GREEN}✓ 项目设置成功！${NC}"
}

# 交互式配置环境变量
configure_env() {
    echo -e "${CYAN}:: 请配置基本环境变量 (直接按 Enter 将使用默认值)。${NC}"
    
    local current_port="3000"
    local current_sub_path="sub"

    read -p "$(echo -e ${GREEN}"请输入服务监听端口 [${current_port}]: "${NC})" PORT
    read -p "$(echo -e ${GREEN}"请输入订阅访问路径 [${current_sub_path}]: "${NC})" SUB_PATH

    PORT=${PORT:-$current_port}
    SUB_PATH=${SUB_PATH:-$current_sub_path}

    echo "PORT=\"${PORT}\"" > "$ENV_FILE"
    echo "SUB_PATH=\"${SUB_PATH}\"" >> "$ENV_FILE"

    echo -e "${GREEN}✓ 配置已保存到 ${ENV_FILE}${NC}"
    echo "   提示: 您可以稍后手动编辑此文件以添加 UUID, NEZHA_KEY 等高级变量。"
}

# 启动应用
# $1: 模式 (auto 或 manual)
start_app() {
    if [ -f "$PID_FILE" ]; then
        echo -e "${YELLOW}应用已在运行 (PID: $(cat $PID_FILE))。无需重复启动。${NC}"
        if [ "$1" == "manual" ]; then read -p "按 Enter 返回..." ; fi
        return
    fi

    echo -e "${CYAN}:: 正在启动 app.py ...${NC}"
    cd "$REPO_DIR"
    set -a # allexport, 自动导出 .env 中的所有变量
    if [ -f ".env" ]; then source ".env"; fi
    set +a
    
    nohup python3 app.py > app.log 2>&1 &
    echo $! > app.pid
    
    cd ..
    
    echo -e "${GREEN}✓ 应用已在后台启动。PID: $(cat $PID_FILE)${NC}"
    echo "   日志文件位于: ${LOG_FILE}"
    
    if [ "$1" == "manual" ]; then
        read -p "按 Enter 返回主菜单..."
    else
        echo -e "${CYAN}:: 等待服务初始化...${NC}"
        sleep 3
    fi
}

# 显示订阅信息
# $1: 模式 (auto 或 manual)
show_subscription() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${RED}错误: 应用未运行。请先启动应用。${NC}"
        if [ "$1" == "manual" ]; then read -p "按 Enter 返回..." ; fi
        return
    fi
    
    local port=$(grep 'PORT=' "$ENV_FILE" | cut -d '=' -f 2 | tr -d '"')
    local sub_path=$(grep 'SUB_PATH=' "$ENV_FILE" | cut -d '=' -f 2 | tr -d '"')
    local sub_url="http://127.0.0.1:${port}/${sub_path}"
    
    echo -e "${CYAN}:: 正在从以下URL获取订阅信息:${NC}"
    echo -e "${YELLOW}   ${sub_url}${NC}"
    echo "--------------------------------------------------"
    
    local content=$(curl -s --max-time 5 "$sub_url")
    
    if [ -z "$content" ]; then
        echo -e "${RED}获取订阅失败！${NC}"
        echo -e "   请检查日志 (tail -f ${LOG_FILE}) 确认服务是否出错。"
    else
        echo -e "${GREEN}✓ 获取成功！订阅内容如下:${NC}"
        echo "$content"
    fi
    echo "--------------------------------------------------"

    if [ "$1" == "manual" ]; then read -p "按 Enter 返回主菜单..."; fi
}

# 停止应用
stop_app() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}应用未在运行。${NC}"
    else
        local pid=$(cat "$PID_FILE")
        echo -e "${CYAN}:: 正在停止应用 (PID: $pid)...${NC}"
        kill "$pid" &>/dev/null
        sleep 1
        if ps -p "$pid" > /dev/null; then kill -9 "$pid" &>/dev/null; fi
        rm -f "$PID_FILE"
        echo -e "${GREEN}✓ 应用已停止。${NC}"
    fi
    read -p "按 Enter 返回主菜单..."
}

# 清理环境
cleanup() {
    if [ -f "$PID_FILE" ]; then
        echo -e "${RED}错误: 应用正在运行。请先从菜单停止应用。${NC}";
    else
        echo -e "${RED}警告: 这将永久删除整个 '${REPO_DIR}' 目录！${NC}"
        read -p "您确定要继续吗? [y/N]: " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            echo -e "${CYAN}:: 正在删除 ${REPO_DIR}...${NC}"; rm -rf "$REPO_DIR"
            echo -e "${GREEN}✓ 清理完成。${NC}"
        else
            echo "操作已取消。"
        fi
    fi
    read -p "按 Enter 返回主菜单..."
}


# --- 主菜单 (后续运行时显示) ---
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}===============================================${NC}"
        echo -e "${CYAN}      python-xray-argo 项目管理菜单      ${NC}"
        echo -e "${CYAN}===============================================${NC}"
        echo -e " ${GREEN}1.${NC} ${CYAN}启动${NC}应用服务"
        echo -e " ${GREEN}2.${NC} ${CYAN}获取/显示${NC}订阅信息"
        echo -e " ${GREEN}3.${NC} ${RED}停止${NC}应用服务"
        echo -e " ${GREEN}4.${NC} 查看实时日志 (Ctrl+C 退出)"
        echo -e " ${GREEN}5.${NC} ${RED}卸载/清理${NC}所有项目文件"
        echo -e " ${YELLOW}6.${NC} 退出"
        echo
        
        if [ -f "$PID_FILE" ]; then echo -e "当前状态: ${GREEN}运行中 (PID: $(cat $PID_FILE))${NC}";
        else echo -e "当前状态: ${RED}已停止${NC}"; fi

        read -p "请输入您的选择 [1-6]: " choice

        case $choice in
            1) start_app "manual" ;;
            2) show_subscription "manual" ;;
            3) stop_app ;;
            4) clear; echo "按 CTRL+C 退出日志查看"; tail -f "$LOG_FILE" ;;
            5) cleanup ;;
            6) exit 0 ;;
            *) echo -e "${RED}无效输入...${NC}"; sleep 1 ;;
        esac
    done
}


# --- 脚本主逻辑 ---
# 判断是否为首次运行
if [ ! -d "$REPO_DIR" ]; then
    # --- 首次运行的自动化流程 ---
    clear
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${CYAN}    欢迎使用! 检测到是首次运行，将开始自动化安装...    ${NC}"
    echo -e "${CYAN}===============================================${NC}"
    
    check_dependencies
    echo
    setup_project
    echo
    configure_env
    echo
    start_app "auto"
    echo
    show_subscription "auto"
    
    echo -e "\n${GREEN}====================== 安装完成 ======================${NC}"
    echo -e "${GREEN}✓ 应用已在后台成功运行！${NC}"
    echo -e "您现在可以复制上面的订阅内容或链接进行使用。"
    echo -e "您可以随时再次运行此脚本 (${YELLOW}./run_project.sh${NC}) 来打开管理菜单，"
    echo -e "进行 ${CYAN}停止服务${NC} 或 ${RED}卸载${NC} 等操作。"
    echo -e "========================================================"

else
    # --- 后续运行，显示管理菜单 ---
    main_menu
fi
