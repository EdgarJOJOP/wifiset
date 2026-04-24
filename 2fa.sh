#!/bin/sh

# 检查权限
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本。"
  exit 1
fi

# 1. 环境检测
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ -f /etc/openwrt_release ]; then
    OS="openwrt"
else
    echo "未能识别的系统。"
    exit 1
fi

echo "检测到系统类型: $OS"

# 2. 安装软件包
echo "正在安装 Google Authenticator 和 OpenSSH..."
if [ "$OS" = "openwrt" ]; then
    opkg update
    opkg install openssh-server-pam google-authenticator-libpam
else
    apt-get update
    apt-get install -y libpam-google-authenticator openssh-server
fi

# 3. 选择认证模式
echo "------------------------------------------------"
echo "请选择 SSH 认证组合方案:"
echo "1) 公钥 + 2FA"
echo "2) 密码 + 2FA"
echo "3) 公钥 + 密码 + 2FA"
echo "------------------------------------------------"
printf "请输入选项 [1-3]: "
read AUTH_CHOICE

case "$AUTH_CHOICE" in
    1)
        AUTH_METHOD="publickey,keyboard-interactive"
        echo "已选择: 公钥 + 2FA"
        ;;
    2)
        AUTH_METHOD="password,keyboard-interactive"
        echo "已选择: 密码 + 2FA"
        ;;
    3)
        AUTH_METHOD="publickey,password,keyboard-interactive"
        echo "已选择: 公钥 + 密码 + 2FA"
        ;;
    *)
        AUTH_METHOD="publickey,keyboard-interactive"
        echo "无效选项，默认使用方案 1 (公钥 + 2FA)"
        ;;
esac

# 4. 配置 PAM (/etc/pam.d/sshd)
PAM_FILE="/etc/pam.d/sshd"
if [ -f "$PAM_FILE" ]; then
    cp "$PAM_FILE" "${PAM_FILE}.bak"
    
    # 注释掉包含 common-auth 的行 (Debian/Ubuntu 常见)
    sed -i 's/^@include common-auth/#@include common-auth/' "$PAM_FILE"
    sed -i 's/^auth    include      common-auth/#auth    include      common-auth/' "$PAM_FILE"
    
    # 如果选择了包含“密码”的方案，需要在 PAM 中显式添加 unix 认证，否则密码会被跳过
    case "$AUTH_METHOD" in
        *password*)
            if ! grep -q "pam_unix.so" "$PAM_FILE"; then
                # 在文件顶部附近添加，确保它在 google_authenticator 之前或配合使用
                echo "auth [success=1 default=ignore] pam_unix.so nullok" >> "$PAM_FILE"
            fi
            ;;
    esac

    # 添加 google-authenticator 模块
    if ! grep -q "pam_google_authenticator.so" "$PAM_FILE"; then
        echo "auth required pam_google_authenticator.so" >> "$PAM_FILE"
    fi
    echo "PAM 配置文件已更新。"
else
    echo "错误: 未找到 $PAM_FILE"
    exit 1
fi

# 5. 配置 SSHD (/etc/ssh/sshd_config)
SSHD_CONFIG="/etc/ssh/sshd_config"
[ -f "$SSHD_CONFIG" ] && cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# 辅助函数：修改或添加配置项
set_config() {
    key="$1"
    val="$2"
    if grep -q "^#\?$key" "$SSHD_CONFIG"; then
        sed -i "s|^#\?$key.*|$key $val|" "$SSHD_CONFIG"
    else
        echo "$key $val" >> "$SSHD_CONFIG"
    fi
}

set_config "PermitRootLogin" "yes"
set_config "PubkeyAuthentication" "yes"
set_config "UsePAM" "yes"
set_config "KbdInteractiveAuthentication" "yes"
set_config "ChallengeResponseAuthentication" "yes"

# 设置 AuthenticationMethods
if grep -q "^AuthenticationMethods" "$SSHD_CONFIG"; then
    sed -i "s|^AuthenticationMethods.*|AuthenticationMethods $AUTH_METHOD|" "$SSHD_CONFIG"
else
    echo "AuthenticationMethods $AUTH_METHOD" >> "$SSHD_CONFIG"
fi

echo "SSHD 配置文件已更新。"

# 6. 生成密钥
echo "------------------------------------------------"
echo "正在为当前用户 $(whoami) 生成 2FA 密钥..."
echo "请在手机上打开 Google Authenticator 扫码。"
echo "建议后续问题全部输入 'y'。"
echo "------------------------------------------------"
google-authenticator

# 7. 重启服务
echo "正在重启 SSH 服务..."
if [ "$OS" = "openwrt" ]; then
    /etc/init.d/sshd restart
else
    systemctl restart ssh
fi

echo "------------------------------------------------"
echo "设置完成！"
echo "认证要求: $AUTH_METHOD"
echo "!!! 请务必保留当前窗口，新开一个终端窗口测试登录 !!!"
echo "------------------------------------------------"
