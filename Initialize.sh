#!/bin/bash

curl -Oks https://raw.githubusercontent.com/Morton-L/HeadScript_Linux/main/loader.sh
source loader.sh font error TCPCC

trap _exit INT QUIT TERM
# 脚本已终止
_exit() {
    red "\n脚本已终止.\n"
    exit 1
}

function ExternalEnv(){
	# 系统信息获取
	getLinuxKernelVersion
	getLinuxOSRelease
	getLinuxOSVersion
	OSVersionCheck
	TCPCC
}

# 检测Linux系统发行版本
function getLinuxOSRelease(){
    if [[ -f /etc/redhat-release ]]; then
        osRelease="centos"
        osSystemPackage="yum"
    elif cat /etc/issue | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
    elif cat /proc/version | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
    fi
}

# 检测系统版本号
function getLinuxOSVersion(){
    if [[ -s /etc/redhat-release ]]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
    else
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/issue)
    fi

    # https://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        source /etc/os-release
        osInfo=$NAME
        osReleaseVersionNo=$VERSION_ID

        if [ -n $VERSION_CODENAME ]; then
            osReleaseVersionCodeName=$VERSION_CODENAME
        fi
	
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        osInfo=$(lsb_release -si)
        osReleaseVersionNo=$(lsb_release -sr)
	
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        osInfo=$DISTRIB_ID
        osReleaseVersionNo=$DISTRIB_RELEASE
	
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        osInfo=Debian
        osReleaseVersion=$(cat /etc/debian_version)
        osReleaseVersionNo=$(sed 's/\..*//' /etc/debian_version)
	
    elif [ -f /etc/redhat-release ]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
	
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        osInfo=$(uname -s)
        osReleaseVersionNo=$(uname -r)
    fi
}

# 检测内核版本
function getLinuxKernelVersion(){
	# 以"-"为分割符号打印第一个值
	LinuxKernelVersion=$(uname -r | awk -F "-" '{print $1}')
}

# 系统版本检查
function OSVersionCheck(){

    if [ "$osRelease" == "centos" ]; then
        if  [[ ${osReleaseVersionNo} -lt "6" ]]; then
            ErrorInfo=" 本脚本不支持 CentOS 6 或更早的版本"
            Error
        fi
    else
        ErrorInfo=" 本脚本不支持非centos系统"
        Error
    fi

}

# 系统检查
function OSCheck(){
# 识别系统
if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
    ErrorInfo=" 目前仅支持CentOS操作系统"
fi
}

# 安装依赖软件
function InstallDependentSoftware(){
	green " =================================================="
	green " 安装依赖软件..."
	green " =================================================="
	$osSystemPackage install -y wget
}

# 更新内核
function UpdateKernel(){
	green " =================================================="
	green " 导入ELrepo公钥"
	green " =================================================="
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	
	# 判断执行结果
	if [ $? -ne 0 ]; then
		ErrorInfo=" 导入ELrepo公钥失败"
		Error
	fi
	
	green " =================================================="
	green " 获取内核版本信息"
	green " =================================================="
	
	elrepo_kernel_version=($(wget -qO- https://elrepo.org/linux/kernel/el8/x86_64/RPMS | awk -F'>'$UpdateKernelVersion'-' '/>'$UpdateKernelVersion'-[4-9]./{print $2}' | cut -d- -f1 | sort -V)[-1])
	
    if [ ${elrepo_kernel_version} == "[-1]" ]; then
        ErrorInfo=" 无法获取最新的内核版本号"
		Error
    else
		green " =================================================="
        green " 最新 ${UpdateKernelVersion} 版内核版本号为 ${elrepo_kernel_version}" 
		green " =================================================="
    fi
	
	if [ "${LinuxKernelVersion}" = "${elrepo_kernel_version}" ]; then 
            red "当前系统内核版本已经是 ${elrepo_kernel_version} 无需更新! "
			sleep 5s
            main
    fi
        
    if [ "${osReleaseVersionNo}" -eq 7 ]; then
        # https://computingforgeeks.com/install-linux-kernel-5-on-centos-7/

        # https://elrepo.org/linux/kernel/
        # https://elrepo.org/linux/kernel/el7/x86_64/RPMS/
    
        yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
   
    elif [ "${osReleaseVersionNo}" -eq 8 ]; then
        # https://elrepo.org/linux/kernel/el8/x86_64/RPMS/
            
        yum install -y https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm

    else
        ErrorInfo=" 不支持 CentOS 7 和 8 以外的其他版本"
        Error
    fi
		
	yum -y --enablerepo=elrepo-kernel install ${UpdateKernelVersion}
	
	# 判断执行结果
	if [ $? -ne 0 ]; then
		ErrorInfo=" 内核安装失败...请查看日志"
		Error
	fi

}

# 更新系统并保持内核版本
function SysUpdate() {
	if [ "${osReleaseVersionNo}" -eq 7 ]; then
        KernelVersion=$(grub2-editenv list | awk -F "=" '{print $2}')
		yum update -y
		if [ $? -ne 0 ]; then
			ErrorInfo=" 系统更新失败...请查看日志"
			Error
		fi
		grub2-set-default "$KernelVersion"
    elif [ "${osReleaseVersionNo}" -eq 8 ]; then
        KernelVersion=$(grubby --default-kernel)
		yum update -y
		if [ $? -ne 0 ]; then
			ErrorInfo=" 系统更新失败...请查看日志"
			Error
		fi
		grubby --set-default $KernelVersion
    else
        ErrorInfo=" 不支持 CentOS 7 和 8 以外的其他版本"
        Error
    fi

}

# 配置登录公钥
function SetAuthorizedKeys(){

	if [ -d "/root/.ssh/" ];then
		if [ -f "/root/.ssh/authorized_keys" ];then
			read -p " SSH公钥文件存在,是否替换?[Y or Other]" HaveFile
			[ -z "${HaveFile}" ] && HaveFile="Y"
			if [[ $HaveFile == [Yy] ]]; then
				SetAuthorizedKeys=1
				rm -rf /root/.ssh/authorized_keys
			else
				SetAuthorizedKeys=0
				yellow " 用户选择不替换"
			fi
			
		else
			SetAuthorizedKeys=1
			touch /root/.ssh/authorized_keys
		fi
	else
		mkdir .ssh
		SetAuthorizedKeys
	fi
	if [ ! -n "$authorized_keys" ]; then
		if [[ $SetAuthorizedKeys == 1 ]]; then
			read -p " 请输入authorized_keys文件内容(SSH公钥,单行内容) :" authorized_keys
			green " =================================================="
			green " 将公钥写入文件"
			green " =================================================="
			echo "${authorized_keys}" > /root/.ssh/authorized_keys
		fi
	
		green " =================================================="
		green " 调整公钥权限"
		green " =================================================="
		chmod 600 /root/.ssh/authorized_keys
	fi
	
}

# 配置SSH服务
function SetPubkeyAuthenticationConfig(){
	
	
	ConfigCheck=$(grep "PasswordAuthentication yes" /etc/ssh/sshd_config)
	if [ ! -n "$ConfigCheck" ]; then
		echo
	else
		sed -i 's/PasswordAuthentication yes/\#PasswordAuthentication yes/g' /etc/ssh/sshd_config
	fi
	ConfigCheck=$(grep "PasswordAuthentication no" /etc/ssh/sshd_config)
	if [ ! -n "$ConfigCheck" ]; then
		echo
	else
		sed -i 's/PasswordAuthentication no/\#PasswordAuthentication yes/g' /etc/ssh/sshd_config
	fi
	sed -i 's/\#\#PasswordAuthentication yes/\#PasswordAuthentication yes/g' /etc/ssh/sshd_config
	sed -i '0,/\#PasswordAuthentication yes/s/\#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
	
	ConfigCheck=$(grep "PubkeyAuthentication yes" /etc/ssh/sshd_config)
	if [ ! -n "$ConfigCheck" ]; then
		echo
	else
		sed -i 's/PubkeyAuthentication yes/\#PubkeyAuthentication yes/g' /etc/ssh/sshd_config
	fi
	ConfigCheck=$(grep "PubkeyAuthentication no" /etc/ssh/sshd_config)
	if [ ! -n "$ConfigCheck" ]; then
		echo
	else
		sed -i 's/PubkeyAuthentication no/\#PubkeyAuthentication yes/g' /etc/ssh/sshd_config
	fi
	sed -i 's/\#\#PubkeyAuthentication yes/\#PubkeyAuthentication yes/g' /etc/ssh/sshd_config
	sed -i '0,/\#PubkeyAuthentication yes/s/\#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
	
	
	green " =================================================="
	green " 参数调整完成,重启SSH服务..."
	green " =================================================="
	sleep 2s
	
	systemctl restart sshd.service
	# 判断执行结果
	if [ $? -ne 0 ]; then
		ErrorInfo=" >>!!!警告!!!<<   SSH服务启动失败,请查看日志."
		Error
	fi

}

# 配置GoogleBBR功能
function GoogleBBR(){
	BBRInfo=$(lsmod | grep bbr)
	if [ ! -n "$BBRInfo" ]; then
		cat >> "/etc/sysctl.conf" <<-EOF
# Google BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
		green " =================================================="
		green " 配置调整完成,重载配置..."
		green " =================================================="
		sleep 2s
		sysctl -p
		BBRInfo=$(lsmod | grep bbr)
		green " =================================================="
		green " BBR Info:   ${BBRInfo}"
		green " =================================================="
		sleep 3s
	else
		green " =================================================="
		bold " 当前已经开启BBR"
		green " =================================================="
		green " BBR Info:   ${BBRInfo}"
		green " =================================================="
		sleep 2s
	fi
}

# 配置TCPFastOpen功能
function TCPFastOpen(){
	
	ConfigCheck=$(grep "net.ipv4.tcp_fastopen = 3" /etc/sysctl.conf)
	if [ ! -n "$ConfigCheck" ]; then
		cat >> "/etc/sysctl.conf" <<-EOF
# TCP Fast Open
net.ipv4.tcp_fastopen = 3
EOF
		green " =================================================="
		green " 配置调整完成,重载配置..."
		green " =================================================="
		sleep 2s
		sysctl -p
	else
		green " =================================================="
		bold " 当前已经开启TCP Fast Open"
		green " =================================================="
		sleep 2s
	fi
}



# 主界面
function main(){
    
	green " =================================================="
	bold  " 欢迎使用一键脚本"
	green " =================================================="
	green " 系统信息:     ${osInfo}, ${osRelease},  "
	green " 系统版本:     ${osReleaseVersionNo}, ${osReleaseVersion},"
	green " 内核版本:     ${LinuxKernelVersion},"
	green " 包管理器:     ${osSystemPackage}"
	green " TCP拥塞控制:  ${tcpcc}"
	green " =================================================="
	yellow "    1 .更新长期支持版内核(lt)"
	yellow "    2 .更新最新稳定版内核(ml)"
	yellow "    3 .更新系统(不影响内核)"
	yellow "    4 .密钥登录"
	yellow "    5 .开启TCP Fast Open"
	yellow "    6 .开启Google BBR"
	yellow "    r .重启       q .退出"
	green " =================================================="
	read -p " 请选择功能(默认:1) [1-9.q] :" Main
    [ -z "${Main}" ] && Main="1"
	
	
	if [[ $Main == 1 ]]; then
		UpdateKernelVersion="kernel-lt"
		InstallDependentSoftware
		UpdateKernel
		main
	fi
	
	if [[ $Main == 2 ]]; then
		UpdateKernelVersion="kernel-ml"
		InstallDependentSoftware
		UpdateKernel
		main
	fi
	
	if [[ $Main == 3 ]]; then
		SysUpdate
		main
	fi
	
	if [[ $Main == 4 ]]; then
		SetAuthorizedKeys
		SetPubkeyAuthenticationConfig
		main
	fi
	
	if [[ $Main == 5 ]]; then
		TCPFastOpen
		main
	fi
	
	if [[ $Main == 6 ]]; then
		GoogleBBR
		main
	fi
	
	if [[ $Main == r ]]; then
		green "Ok...Rebooting!"
		sleep 3s
		reboot
	fi
	
	if [[ $Main == q ]]; then
		green "Ok...Bye!"
		exit
	fi
	
	
	
	
	
}


ExternalEnv
OSCheck
main