#!/bin/bash

#-----------------------------------------------------------------------------
# python-xray-argo 项目部署与管理脚本 (v2 - 优化首次运行体验)
#
# 功能:
#   - 首次运行自动完成安装、配置、启动和显示订阅。
#   - 后续运行提供管理菜单 (启动/停止/清理等)。
#
# 使用方法:
#   1. 将此脚本保存为 run_project.sh
#   2. 授予执行权限: chmod +x run_project.sh
#   3. 运行脚本: ./run_project.sh
#-----------------------------------------------------------------------------

# --- 全局变量和配置 ---
# 颜色代码
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 项目信息
REPO_URL="https://github.com/eooce/python-xray-argo.git"
REPO_DIR="python-xray-argo"
PID_FILE="${REPO_DIR}/app.pid"
LOG_FILE="${REPO_DIR}/app.log"
ENV_FILE="${REPO_DIR}/.env"


# --- 核心功能函数 ---

# 检查依赖项
check_dependencies() {
    echo -e "${CYAN}:: 正在检查所需依赖 (git, python3, pip)...${NC}"
    local missing_deps=0
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
