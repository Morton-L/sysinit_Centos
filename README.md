# sysinit_Centos

yum install -y epel-release && yum install -y screen && screen -S shell

yum install -y wget && wget --no-check-certificate https://raw.githubusercontent.com/Morton-L/sysinit_Centos/main/Initialize.sh && chmod +x Initialize.sh && ./Initialize.sh

如果中途ssh断了可以使用screen -r恢复