#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 生成UUID函数
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    fi
}

# 清屏
clear

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Python Xray Argo 交互式配置脚本    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# 选择模式
echo -e "${YELLOW}请选择配置模式:${NC}"
echo -e "${BLUE}1) 极速模式 - 只修改UUID并启动${NC}"
echo -e "${BLUE}2) 完整模式 - 详细配置所有选项${NC}"
echo
read -p "请输入选择 (1/2): " MODE_CHOICE

# 检查并安装依赖
echo -e "${BLUE}检查并安装依赖...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install requests
fi

# 下载完整仓库
PROJECT_DIR="python-xray-argo"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载完整仓库...${NC}"
    if command -v git &> /dev/null; then
        git clone https://github.com/eooce/python-xray-argo.git
    else
        echo -e "${YELLOW}Git未安装，使用wget下载...${NC}"
        wget -q https://github.com/eooce/python-xray-argo/archive/refs/heads/main.zip -O python-xray-argo.zip
        if command -v unzip &> /dev/null; then
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main python-xray-argo
            rm python-xray-argo.zip
        else
            echo -e "${YELLOW}正在安装 unzip...${NC}"
            sudo apt-get install -y unzip
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main python-xray-argo
            rm python-xray-argo.zip
        fi
    fi
    
    if [ $? -ne 0 ] || [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    fi
fi

# 进入项目目录
cd "$PROJECT_DIR"

echo -e "${GREEN}依赖安装完成！${NC}"
echo

# 检查app.py文件是否存在
if [ ! -f "app.py" ]; then
    echo -e "${RED}未找到app.py文件！${NC}"
    exit 1
fi

# 备份原文件
cp app.py app.py.backup
echo -e "${YELLOW}已备份原始文件为 app.py.backup${NC}"

if [ "$MODE_CHOICE" = "1" ]; then
    # 极速模式
    echo -e "${BLUE}=== 极速模式 ===${NC}"
    echo
    
    # UUID配置
    echo -e "${YELLOW}当前UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi
    
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"
    
    echo
    echo -e "${GREEN}极速配置完成！正在启动服务...${NC}"
    echo
    
else
    # 完整模式
    echo -e "${BLUE}=== 完整配置模式 ===${NC}"
    echo
    
    # UUID配置
    echo -e "${YELLOW}当前UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"

    # 节点名称配置
    echo -e "${YELLOW}当前节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)${NC}"
    read -p "请输入节点名称 (留空保持不变): " NAME_INPUT
    if [ -n "$NAME_INPUT" ]; then
        sed -i "s/NAME = os.environ.get('NAME', '[^']*')/NAME = os.environ.get('NAME', '$NAME_INPUT')/" app.py
        echo -e "${GREEN}节点名称已设置为: $NAME_INPUT${NC}"
    fi

    # 端口配置
    echo -e "${YELLOW}当前服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)${NC}"
    read -p "请输入服务端口 (留空保持不变): " PORT_INPUT
    if [ -n "$PORT_INPUT" ]; then
        sed -i "s/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or [0-9]*)/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or $PORT_INPUT)/" app.py
        echo -e "${GREEN}端口已设置为: $PORT_INPUT${NC}"
    fi

    # 优选IP配置
    echo -e "${YELLOW}当前优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选IP/域名 (留空保持不变): " CFIP_INPUT
    if [ -n "$CFIP_INPUT" ]; then
        sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', '$CFIP_INPUT')/" app.py
        echo -e "${GREEN}优选IP已设置为: $CFIP_INPUT${NC}"
    fi

    # 优选端口配置
    echo -e "${YELLOW}当前优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选端口 (留空保持不变): " CFPORT_INPUT
    if [ -n "$CFPORT_INPUT" ]; then
        sed -i "s/CFPORT = int(os.environ.get('CFPORT', '[^']*'))/CFPORT = int(os.environ.get('CFPORT', '$CFPORT_INPUT'))/" app.py
        echo -e "${GREEN}优选端口已设置为: $CFPORT_INPUT${NC}"
    fi

    # Argo端口配置
    echo -e "${YELLOW}当前Argo端口: $(grep "ARGO_PORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入 Argo 端口 (留空保持不变): " ARGO_PORT_INPUT
    if [ -n "$ARGO_PORT_INPUT" ]; then
        sed -i "s/ARGO_PORT = int(os.environ.get('ARGO_PORT', '[^']*'))/ARGO_PORT = int(os.environ.get('ARGO_PORT', '$ARGO_PORT_INPUT'))/" app.py
        echo -e "${GREEN}Argo端口已设置为: $ARGO_PORT_INPUT${NC}"
    fi

    # 订阅路径配置
    echo -e "${YELLOW}当前订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入订阅路径 (留空保持不变): " SUB_PATH_INPUT
    if [ -n "$SUB_PATH_INPUT" ]; then
        sed -i "s/SUB_PATH = os.environ.get('SUB_PATH', '[^']*')/SUB_PATH = os.environ.get('SUB_PATH', '$SUB_PATH_INPUT')/" app.py
        echo -e "${GREEN}订阅路径已设置为: $SUB_PATH_INPUT${NC}"
    fi

    # 高级配置选项
    echo
    echo -e "${YELLOW}是否配置高级选项? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG

    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        # 上传URL配置
        echo -e "${YELLOW}当前上传URL: $(grep "UPLOAD_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入上传URL (留空保持不变): " UPLOAD_URL_INPUT
        if [ -n "$UPLOAD_URL_INPUT" ]; then
            sed -i "s|UPLOAD_URL = os.environ.get('UPLOAD_URL', '[^']*')|UPLOAD_URL = os.environ.get('UPLOAD_URL', '$UPLOAD_URL_INPUT')|" app.py
            echo -e "${GREEN}上传URL已设置${NC}"
        fi

        # 项目URL配置
        echo -e "${YELLOW}当前项目URL: $(grep "PROJECT_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入项目URL (留空保持不变): " PROJECT_URL_INPUT
        if [ -n "$PROJECT_URL_INPUT" ]; then
            sed -i "s|PROJECT_URL = os.environ.get('PROJECT_URL', '[^']*')|PROJECT_URL = os.environ.get('PROJECT_URL', '$PROJECT_URL_INPUT')|" app.py
            echo -e "${GREEN}项目URL已设置${NC}"
        fi

        # 自动保活配置
        echo -e "${YELLOW}当前自动保活状态: $(grep "AUTO_ACCESS = " app.py | grep -o "'[^']*'" | tail -1 | tr -d "'")${NC}"
        echo -e "${YELLOW}是否启用自动保活? (y/n)${NC}"
        read -p "> " AUTO_ACCESS_INPUT
        if [ "$AUTO_ACCESS_INPUT" = "y" ] || [ "$AUTO_ACCESS_INPUT" = "Y" ]; then
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'true')/" app.py
            echo -e "${GREEN}自动保活已启用${NC}"
        elif [ "$AUTO_ACCESS_INPUT" = "n" ] || [ "$AUTO_ACCESS_INPUT" = "N" ]; then
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'false')/" app.py
            echo -e "${GREEN}自动保活已禁用${NC}"
        fi

        # 哪吒配置
        echo -e "${YELLOW}当前哪吒服务器: $(grep "NEZHA_SERVER = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入哪吒服务器地址 (留空保持不变): " NEZHA_SERVER_INPUT
        if [ -n "$NEZHA_SERVER_INPUT" ]; then
            sed -i "s|NEZHA_SERVER = os.environ.get('NEZHA_SERVER', '[^']*')|NEZHA_SERVER = os.environ.get('NEZHA_SERVER', '$NEZHA_SERVER_INPUT')|" app.py
            
            echo -e "${YELLOW}当前哪吒端口: $(grep "NEZHA_PORT = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入哪吒端口 (v1版本留空): " NEZHA_PORT_INPUT
            if [ -n "$NEZHA_PORT_INPUT" ]; then
                sed -i "s|NEZHA_PORT = os.environ.get('NEZHA_PORT', '[^']*')|NEZHA_PORT = os.environ.get('NEZHA_PORT', '$NEZHA_PORT_INPUT')|" app.py
            fi
            
            echo -e "${YELLOW}当前哪吒密钥: $(grep "NEZHA_KEY = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入哪吒密钥: " NEZHA_KEY_INPUT
            if [ -n "$NEZHA_KEY_INPUT" ]; then
                sed -i "s|NEZHA_KEY = os.environ.get('NEZHA_KEY', '[^']*')|NEZHA_KEY = os.environ.get('NEZHA_KEY', '$NEZHA_KEY_INPUT')|" app.py
            fi
            echo -e "${GREEN}哪吒配置已设置${NC}"
        fi

        # Argo固定隧道配置
        echo -e "${YELLOW}当前Argo域名: $(grep "ARGO_DOMAIN = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入 Argo 固定隧道域名 (留空保持不变): " ARGO_DOMAIN_INPUT
        if [ -n "$ARGO_DOMAIN_INPUT" ]; then
            sed -i "s|ARGO_DOMAIN = os.environ.get('ARGO_DOMAIN', '[^']*')|ARGO_DOMAIN = os.environ.get('ARGO_DOMAIN', '$ARGO_DOMAIN_INPUT')|" app.py
            
            echo -e "${YELLOW}当前Argo密钥: $(grep "ARGO_AUTH = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入 Argo 固定隧道密钥: " ARGO_AUTH_INPUT
            if [ -n "$ARGO_AUTH_INPUT" ]; then
                sed -i "s|ARGO_AUTH = os.environ.get('ARGO_AUTH', '[^']*')|ARGO_AUTH = os.environ.get('ARGO_AUTH', '$ARGO_AUTH_INPUT')|" app.py
            fi
            echo -e "${GREEN}Argo固定隧道配置已设置${NC}"
        fi

        # Telegram配置
        echo -e "${YELLOW}当前Bot Token: $(grep "BOT_TOKEN = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入 Telegram Bot Token (留空保持不变): " BOT_TOKEN_INPUT
        if [ -n "$BOT_TOKEN_INPUT" ]; then
            sed -i "s|BOT_TOKEN = os.environ.get('BOT_TOKEN', '[^']*')|BOT_TOKEN = os.environ.get('BOT_TOKEN', '$BOT_TOKEN_INPUT')|" app.py
            
            echo -e "${YELLOW}当前Chat ID: $(grep "CHAT_ID = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入 Telegram Chat ID: " CHAT_ID_INPUT
            if [ -n "$CHAT_ID_INPUT" ]; then
                sed -i "s|CHAT_ID = os.environ.get('CHAT_ID', '[^']*')|CHAT_ID = os.environ.get('CHAT_ID', '$CHAT_ID_INPUT')|" app.py
            fi
            echo -e "${GREEN}Telegram配置已设置${NC}"
        fi
    fi

    echo
    echo -e "${GREEN}完整配置完成！${NC}"
fi

# 显示配置摘要
echo -e "${YELLOW}=== 当前配置摘要 ===${NC}"
echo -e "UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)"
echo -e "节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)"
echo -e "服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)"
echo -e "优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)"
echo -e "优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)"
echo -e "订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)"
echo -e "${YELLOW}========================${NC}"
echo

# 启动服务
echo -e "${BLUE}正在启动服务...${NC}"
echo -e "${YELLOW}当前工作目录：$(pwd)${NC}"
echo

python app.py
