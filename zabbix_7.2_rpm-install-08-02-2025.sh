#!/bin/bash
# Versão 8.2.25 do script de instalação automatizada do Zabbix 7.2 com backup de configurações e verificações pós-instalação
# Criado por André Rodrigues
# Testado em Oracle Linux 9.5, Red Hat Enterprise Linux 9.5 (Plow) e Rocky Linux 9.5 (Blue Onyx)
# VMware® Workstation 17 Pro 17.5.2 build-23775571

# Configura o shell para encerrar em caso de erro e capturar erros em pipes
set -e
set -o pipefail

# Define arquivos de log (na pasta atual)
RESULTS_FILE="./install-zabbix-results.txt"
ERRORS_FILE="./install-zabbix-errors.txt"
> "$RESULTS_FILE"
> "$ERRORS_FILE"

#######################################
# Função de log: registra mensagens com data/hora no arquivo de resultados
#######################################
log_result() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$RESULTS_FILE"
}

# Trap para capturar erros e registrar detalhes
trap 'log_result "Erro na linha ${LINENO}: comando [${BASH_COMMAND}] retornou o código $?"' ERR

# Obtém o número de colunas do terminal (ou usa 80 se não for possível)
COLUMNS=$(tput cols 2>/dev/null || echo 80)

#######################################
# Função para realizar backup de arquivos de configuração
#######################################
backup_config() {
    local file="$1"
    if [ -f "$file" ]; then
        cp -n "$file" "${file}.bak" && log_result "Backup de $file criado em ${file}.bak" || log_result "Erro ao criar backup de $file"
    else
        log_result "Arquivo $file não encontrado. Nenhum backup necessário."
    fi
}

#######################################
# Cabeçalho e disclaimers
#######################################
HEADER_MSG=$(cat <<'EOF'
Zabbix 7.2 | MariaDB | Apache - Script 8.2.25
EOF
)

source /etc/os-release
LINUX_VER=$PRETTY_NAME

DISCLAIMER_EN="$(echo -e "$HEADER_MSG")\n\nDetected system version: $LINUX_VER\n
This is version 8.2.25 of the Zabbix 7.2 automated installation script using MariaDB and Apache.
This script was created by André Rodrigues and tested on Oracle Linux 9.5, RHEL 9.5, and Rocky Linux 9.5 on VMware® Workstation 17 Pro 17.5.2.
For inquiries or permissions, contact: technova.sti@outlook.com
If you were able to install your Zabbix server with little effort, please support via PIX :)
technova.sti@outlook.com
Thank you!
"

DISCLAIMER_ES="$(echo -e "$HEADER_MSG")\n\nVersión del sistema detectada: $LINUX_VER\n
Este script fue creado por André Rodrigues y probado en Oracle Linux 9.5, RHEL 9.5, y Rocky Linux 9.5 en VMware® Workstation 17 Pro 17.5.2.
Para consultas o permisos, contáctenos a: technova.sti@outlook.com
¡Gracias!
"

DISCLAIMER_PT="$(echo -e "$HEADER_MSG")\n\nVersão do sistema detectado: $LINUX_VER\n
Este script foi criado por André Rodrigues e testado em Oracle Linux 9.5, RHEL 9.5 e Rocky Linux 9.5 em VMware® Workstation 17 Pro 17.5.2.
Para dúvidas ou permissões, contate: technova.sti@outlook.com
Obrigado!
"

SEPARATOR="=================================================="
echo -e "$DISCLAIMER_EN" | fold -s -w "$COLUMNS"
echo "$SEPARATOR"
echo -e "$DISCLAIMER_ES" | fold -s -w "$COLUMNS"
echo "$SEPARATOR"
echo -e "$DISCLAIMER_PT" | fold -s -w "$COLUMNS"
echo "$SEPARATOR"

#######################################
# Verifica se o script está sendo executado como root
#######################################
if [[ $EUID -ne 0 ]]; then
    echo "Este script precisa ser executado como root." | tee -a "$RESULTS_FILE"
    exit 1
fi

#######################################
# Define a variável DISTRO_ID a partir de /etc/os-release
#######################################
DISTRO_ID=$ID

#######################################
# Se for RHEL, instala o epel-release necessário
#######################################
if [[ "$DISTRO_ID" == "rhel" ]]; then
    log_result "Distribuição RHEL detectada. Instalando epel-release..."
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
fi

#######################################
# Variáveis de configuração do Zabbix e do MariaDB
#######################################
ZABBIX_DB_NAME="zabbix"
ZABBIX_DB_USER="zabbix"
ZABBIX_DB_PASSWORD="zabbix"
DB_ROOT_PASSWORD="zabbix"  # Senha para o root do MariaDB

log_result "Iniciando a instalação do Zabbix com suporte ao protocolo SNMP..."

#######################################
# Instala o pacote expect, se necessário
#######################################
if ! command -v expect &>/dev/null; then
    log_result "Instalando expect..."
    dnf install -y expect >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
fi

#######################################
# Atualiza o sistema
#######################################
log_result "Atualizando o sistema..."
dnf update -y >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

#######################################
# Configura SELinux para modo permissivo
#######################################
log_result "Configurando SELinux para modo permissivo..."
setenforce 0 >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

#######################################
# Instala o repositório Remi via wget com timeout
#######################################
log_result "Baixando repositório Remi..."
REMI_RPM="remi-release-9.rpm"
wget --timeout=30 -O /tmp/$REMI_RPM https://rpms.remirepo.net/enterprise/$REMI_RPM || { log_result "Falha ao baixar o repositório Remi."; exit 1; }
dnf install -y /tmp/$REMI_RPM >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
rm -f /tmp/$REMI_RPM

#######################################
# Instala e configura Apache
#######################################
log_result "Instalando Apache..."
dnf install -y httpd >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
systemctl enable --now httpd >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
APACHE_VERSION=$(httpd -v | grep "Server version" | awk '{print $3}' | cut -d'/' -f2)
log_result "Versão do Apache instalada: $APACHE_VERSION"

#######################################
# Configura o firewall para HTTP/HTTPS
#######################################
log_result "Configurando firewall para HTTP e HTTPS..."
firewall-cmd --zone=public --add-service=http --permanent >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
firewall-cmd --zone=public --add-service=https --permanent >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
firewall-cmd --reload >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

#######################################
# Instala e configura PHP 8.1
#######################################
log_result "Instalando PHP 8.1 e módulos adicionais..."
dnf module reset php -y >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
dnf module enable php:remi-8.1 -y >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
dnf install -y php php-bcmath php-bz2 php-cli php-common php-curl php-fpm \
    php-gd php-intl php-json php-ldap php-mbstring php-pdo php-sqlite3 php-sodium \
    php-opcache php-xml php-mysqlnd php-zip >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}')
log_result "Versão do PHP instalada: $PHP_VERSION"
php -v >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
if [ ! -d /etc/php.d ]; then
    mkdir -p /etc/php.d >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
fi
cat <<EOF > /etc/php.d/zabbix.ini
; Configuração para o Zabbix – suprime avisos de deprecated e outros
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_NOTICE
display_errors = Off
EOF
systemctl restart httpd php-fpm >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

#######################################
# Instala e configura MariaDB
#######################################
log_result "Instalando MariaDB..."
dnf install -y mariadb-server >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
systemctl start mariadb >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
systemctl enable mariadb >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
MARIADB_VERSION=$(mysql --version | awk '{print $5}' | sed 's/,//')
log_result "Versão do MariaDB instalada: $MARIADB_VERSION"
CONFIG_FILE="/etc/my.cnf.d/mariadb-server.cnf"
if [ -f "$CONFIG_FILE" ]; then
    backup_config "$CONFIG_FILE"
    sed -i 's/^\s*bind-address\s*=.*$/bind-address = 0.0.0.0/' "$CONFIG_FILE" >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
fi
systemctl restart mariadb >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
firewall-cmd --add-service=mysql --permanent >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
firewall-cmd --reload >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
log_result "Automatizando configuração inicial do MariaDB via Expect..."
SECURE_MYSQL=$(expect <<EOF
set timeout 10
spawn mariadb-secure-installation
expect "Enter current password for root (enter for none):"
send "\r"
expect "Set root password? \[Y/n\]"
send "Y\r"
expect "New password:"
send "$DB_ROOT_PASSWORD\r"
expect "Re-enter new password:"
send "$DB_ROOT_PASSWORD\r"
expect "Remove anonymous users? \[Y/n\]"
send "Y\r"
expect "Disallow root login remotely? \[Y/n\]"
send "Y\r"
expect "Remove test database and access to it? \[Y/n\]"
send "Y\r"
expect "Reload privilege tables now? \[Y/n\]"
send "Y\r"
expect eof
EOF
)
log_result "Configuração segura do MariaDB concluída."

#######################################
# Instala fping (dependência do zabbix-server-mysql)
#######################################
if [[ "$DISTRO_ID" =~ (rhel) ]]; then
    log_result "Distribuição RHEL detectada. Instalando fping..."
    dnf install -y fping >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
elif [[ "$DISTRO_ID" =~ (oracle|ol) ]]; then
    log_result "Distribuição Oracle Linux detectada. Instalando fping a partir do repositório EPEL..."
    dnf install -y --enablerepo=ol9_developer_EPEL fping >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
elif [[ "$DISTRO_ID" == "rocky" ]]; then
    log_result "Distribuição Rocky Linux detectada. Instalando fping a partir do repositório EPEL..."
    if ! rpm -q epel-release &>/dev/null; then
        dnf install -y epel-release >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
    fi
    dnf install -y --enablerepo=epel fping >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
fi

#######################################
# Instala pacote zabbix-sql-scripts, se disponível
#######################################
if dnf info zabbix-sql-scripts >/dev/null 2>&1; then
    log_result "Instalando pacote zabbix-sql-scripts..."
    dnf install -y zabbix-sql-scripts >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
else
    log_result "Pacote zabbix-sql-scripts não disponível. Continuando..."
fi

#######################################
# Configuração do repositório do Zabbix
#######################################
if [[ "$DISTRO_ID" =~ (rhel) ]]; then
    log_result "Configurando repositório do Zabbix para RHEL..."
    cat <<EOF > /etc/yum.repos.d/zabbix.repo
[zabbix]
name=Zabbix Repository
baseurl=https://repo.zabbix.com/zabbix/7.2/stable/rhel/9/x86_64/
enabled=1
gpgcheck=0
EOF
    dnf clean all >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
    dnf makecache >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
elif [[ "$DISTRO_ID" =~ (oracle|ol) ]]; then
    log_result "Configurando repositório do Zabbix para Oracle Linux..."
    cat <<EOF > /etc/yum.repos.d/zabbix.repo
[zabbix]
name=Zabbix Repository
baseurl=https://repo.zabbix.com/zabbix/7.2/stable/oracle/9/x86_64/
enabled=1
gpgcheck=0
EOF
    dnf clean all >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
    dnf makecache >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
elif [[ "$DISTRO_ID" == "rocky" ]]; then
    log_result "Configurando repositório do Zabbix para Rocky Linux..."
    cat <<EOF > /etc/yum.repos.d/zabbix.repo
[zabbix]
name=Zabbix Repository
baseurl=https://repo.zabbix.com/zabbix/7.2/stable/rocky/9/x86_64/
enabled=1
gpgcheck=0
EOF
    dnf clean all >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
    dnf makecache >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
else
    log_result "Distribuição não identificada para configuração do repositório do Zabbix."
    exit 1
fi

ZABBIX_VERSION="7.2"
log_result "Versão do Zabbix configurada: $ZABBIX_VERSION"

#######################################
# Instala os pacotes do Zabbix
#######################################
if [[ "$DISTRO_ID" =~ (oracle|ol) ]]; then
    log_result "Instalando pacotes do Zabbix para Oracle Linux..."
    dnf install -y --nogpgcheck --disablerepo=ol9_developer_EPEL --allowerasing \
        zabbix-server-mysql \
        zabbix-web-mysql \
        zabbix-apache-conf \
        zabbix-sql-scripts \
        zabbix-agent2 >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
else
    log_result "Instalando pacotes do Zabbix (desabilitando repositório EPEL)..."
    dnf install -y --nogpgcheck --disablerepo=epel \
        zabbix-server-mysql \
        zabbix-web-mysql \
        zabbix-apache-conf \
        zabbix-sql-scripts \
        zabbix-selinux-policy \
        zabbix-agent2 >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
fi

#######################################
# Configuração do banco de dados do Zabbix
#######################################
log_result "Criando banco de dados e usuários para o Zabbix..."
mysql -uroot -p${DB_ROOT_PASSWORD} <<EOF >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
CREATE DATABASE IF NOT EXISTS ${ZABBIX_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
DROP USER IF EXISTS '${ZABBIX_DB_USER}'@'localhost';
CREATE USER '${ZABBIX_DB_USER}'@'localhost' IDENTIFIED BY '${ZABBIX_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${ZABBIX_DB_NAME}.* TO '${ZABBIX_DB_USER}'@'localhost';
DROP USER IF EXISTS '${ZABBIX_DB_USER}'@'%';
CREATE USER '${ZABBIX_DB_USER}'@'%' IDENTIFIED BY '${ZABBIX_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${ZABBIX_DB_NAME}.* TO '${ZABBIX_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

log_result "Importando esquema inicial do banco de dados do Zabbix..."
SQL_FILE=$(find /usr/share -maxdepth 6 -type f \( -iname "server.sql.gz" -o -iname "create.sql.gz" -o -iname "schema.sql.gz" -o -iname "server.sql" -o -iname "create.sql" -o -iname "schema.sql" \) 2>/dev/null | head -n 1)
if [ -n "$SQL_FILE" ]; then
    log_result "Arquivo de esquema encontrado: $SQL_FILE"
    if [[ "$SQL_FILE" == *.gz ]]; then
        zcat "$SQL_FILE" | mysql --default-character-set=utf8mb4 -u${ZABBIX_DB_USER} -p${ZABBIX_DB_PASSWORD} ${ZABBIX_DB_NAME} >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
    else
        cat "$SQL_FILE" | mysql --default-character-set=utf8mb4 -u${ZABBIX_DB_USER} -p${ZABBIX_DB_PASSWORD} ${ZABBIX_DB_NAME} >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
    fi
else
    log_result "Arquivo de esquema SQL do Zabbix não encontrado. Verifique se o pacote 'zabbix-sql-scripts' está instalado corretamente."
    echo "Erro: Arquivo de esquema SQL do Zabbix não encontrado." >> "$ERRORS_FILE"
    exit 1
fi

log_result "Desativando a opção log_bin_trust_function_creators..."
mysql -uroot -p${DB_ROOT_PASSWORD} -e "SET GLOBAL log_bin_trust_function_creators = 0;" >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

#######################################
# Configuração do arquivo de configuração do Zabbix
#######################################
log_result "Configurando o arquivo de configuração do Zabbix..."
backup_config "/etc/zabbix/zabbix_server.conf"
sed -i "s/^# DBPassword=.*/DBPassword=${ZABBIX_DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
if ! grep -q "^DBPassword=" /etc/zabbix/zabbix_server.conf; then
    echo "DBPassword=${ZABBIX_DB_PASSWORD}" >> /etc/zabbix/zabbix_server.conf
fi
if ! grep -q "^PidFile=" /etc/zabbix/zabbix_server.conf; then
    echo "PidFile=/run/zabbix/zabbix_server.pid" >> /etc/zabbix/zabbix_server.conf
fi

#######################################
# Configura o firewall e diretórios necessários
#######################################
log_result "Configurando o firewall para HTTP e porta 10051 (Zabbix Server)..."
firewall-cmd --add-service=http --permanent >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
firewall-cmd --add-port=10051/tcp --permanent >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
firewall-cmd --reload >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

log_result "Criando diretório /run/zabbix com as permissões adequadas..."
mkdir -p /run/zabbix >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
chown zabbix:zabbix /run/zabbix >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
chmod 775 /run/zabbix >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
cat <<EOF > /etc/tmpfiles.d/zabbix.conf
d /run/zabbix 0775 zabbix zabbix -
EOF

#######################################
# Instala e configura SNMP
#######################################
log_result "Instalando SNMP e utilitários..."
dnf install -y net-snmp net-snmp-utils >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
log_result "Configurando o SNMP..."
if [ -f /etc/snmp/snmpd.conf ]; then
    backup_config "/etc/snmp/snmpd.conf"
    cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bkp >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
fi
cat <<EOF > /etc/snmp/snmpd.conf
# Exemplo de configuração SNMP para monitoramento com Zabbix
rocommunity public 127.0.0.1
syslocation "Servidor Zabbix"
syscontact "Admin <admin@example.com>"
EOF
log_result "Habilitando e iniciando o serviço SNMP..."
systemctl enable --now snmpd >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
log_result "Abrindo porta SNMP no firewall (UDP 161)..."
firewall-cmd --zone=public --add-port=161/udp --permanent >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
firewall-cmd --reload >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

#######################################
# Inicia e habilita os serviços do Zabbix, Apache, PHP-FPM e agente
#######################################
log_result "Iniciando e habilitando os serviços do Zabbix, Apache, PHP-FPM e agente..."
systemctl restart zabbix-server zabbix-agent2 httpd php-fpm >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"
systemctl enable zabbix-server zabbix-agent2 httpd php-fpm >> "$RESULTS_FILE" 2>> "$ERRORS_FILE"

#######################################
# Funções de Verificação Pós-Instalação
#######################################
verify_service() {
    SERVICE_NAME="$1"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_result "Serviço $SERVICE_NAME está ativo."
    else
        log_result "ERRO: Serviço $SERVICE_NAME NÃO está ativo. Tente reiniciá-lo com: systemctl restart $SERVICE_NAME"
    fi
}

post_installation_checks() {
    log_result "Iniciando verificações pós-instalação..."
    verify_service "httpd"
    verify_service "php-fpm"
    verify_service "mariadb"
    verify_service "zabbix-server"
    verify_service "zabbix-agent2"
    verify_service "snmpd"
    log_result "Verificações pós-instalação concluídas."
}

#######################################
# Finaliza a instalação e executa verificações pós-instalação
#######################################
# Executa as verificações pós-instalação
post_installation_checks
HOST_IP=$(hostname -I | awk '{print $1}')
log_result "Instalação concluída! Acesse http://$HOST_IP/zabbix para finalizar a configuração via interface web.


Informações importantes:

Para acessar a instância do banco de dados do Zabbix durante a configuração via interface web, utilize as seguintes credenciais:
Usuário: zabbix
Senha: zabbix

Para realizar o login na interface web do Zabbix após a configuração via interface web, utilize as seguintes credenciais:
Usuário: Admin
Senha: zabbix"
