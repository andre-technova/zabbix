Visão Geral
Este script automatiza a instalação e configuração do Zabbix 7.2 juntamente com MariaDB e Apache em sistemas baseados em Oracle Linux, Red Hat Enterprise Linux e Rocky Linux. O script configura os repositórios necessários, instala dependências (como PHP 8.1, MariaDB, Apache, SNMP, fping etc.), e automatiza a configuração inicial do banco de dados e do ambiente do Zabbix. Além disso, foram implementadas funções de verificação pós-instalação para assegurar que os serviços críticos estejam ativos e funcionando corretamente.

Funcionalidades
Instalação Automática: Configura e instala Apache, PHP 8.1, MariaDB, SNMP, fping e os pacotes do Zabbix.
Configuração de Repositórios: Ajusta a configuração do repositório do Zabbix conforme a distribuição (Oracle Linux, RHEL ou Rocky Linux).
Automatização do Banco de Dados: Cria o banco de dados e os usuários necessários, importa o esquema inicial do Zabbix e desativa a opção log_bin_trust_function_creators.
Verificações Pós-Instalação: Verifica se serviços críticos (Apache, PHP-FPM, MariaDB, Zabbix Server, Zabbix Agent e SNMP) estão ativos, sugerindo ações corretivas se algum serviço não estiver em execução.
Logs Detalhados: Registra todas as ações e erros nos arquivos install-zabbix-results.txt e install-zabbix-errors.txt para facilitar a depuração.
Pré-Requisitos
Sistema Operacional: Oracle Linux 9, Red Hat Enterprise Linux 9 ou Rocky Linux 9.
Conectividade com a Internet: Para baixar pacotes e repositórios.
Privilégios de Root: O script deve ser executado como usuário root.
Ferramentas Básicas: wget, curl, vim, expect (o script instala essas dependências caso não estejam presentes).

Instalação e Configuração
1. Baixar o Script
Salve o script de instalação (por exemplo, zabbix_7.2_rpm-install-08-02-2025.sh) em seu servidor.
2. Conceder Permissão de Execução
No terminal, execute:
bash
chmod +x zabbix_7.2_rpm-install-08-02-2025.sh
3. (Opcional) Criar um Arquivo de Configuração
Você pode criar um arquivo chamado zabbix_install.conf no mesmo diretório para sobrescrever as variáveis padrão. Por exemplo:
bash
# zabbix_install.conf
ZABBIX_VERSION="7.2"
DB_PASSWORD="MinhaSenhaSegura"
LOG_FILE="./zabbix_install.log"
4. Executar o Script
Execute o script como root:
bash
sudo ./zabbix_7.2_rpm-install-08-02-2025.sh

Pós-Instalação e Verificação
Ao final da execução, o script realizará verificações pós-instalação para confirmar que os seguintes serviços estão ativos:

Apache (httpd)
PHP-FPM
MariaDB
Zabbix Server
Zabbix Agent
SNMP (snmpd)
Caso algum serviço não esteja ativo, o script exibirá uma mensagem de erro e sugerirá a reinicialização do serviço com o comando systemctl restart <serviço>.

Resolução de Problemas Comuns
Timeout ou Erro de Download:
Se ocorrerem problemas ao baixar algum repositório (como o Remi), verifique a conectividade do servidor com a Internet. O script utiliza wget com um timeout configurado para evitar erros de conexão. Você pode tentar baixar manualmente o arquivo para verificar.

Serviços Não Iniciados:
Verifique o status dos serviços usando systemctl status <serviço>. Se algum serviço não estiver ativo, tente reiniciá-lo com:

bash
sudo systemctl restart <serviço>
Verifique os logs em install-zabbix-results.txt e install-zabbix-errors.txt para mais informações.

Problemas com o Banco de Dados:
Se houver erros durante a importação do esquema ou criação do banco de dados, confirme se o MariaDB está instalado corretamente e se os comandos SQL foram executados sem erros.

Problemas com Dependências:
O script tenta instalar dependências como fping e expect automaticamente. Caso falhe, tente instalá-las manualmente e execute o script novamente.

Logs
Resultados: As mensagens de log e sucesso são registradas em install-zabbix-results.txt.
Erros: Mensagens de erro são registradas em install-zabbix-errors.txt.

Contribuição
Caso deseje contribuir para aprimorar este script, sinta-se à vontade para enviar sugestões de melhorias ou correções. As sugestões podem incluir:

Modularização adicional do código.
Tratamento avançado de argumentos de linha de comando.
Estratégias aprimoradas de rotação e gestão de logs.
Melhor documentação inline e comentários.

Licença
Este script é protegido por direitos autorais. Para dúvidas ou permissões, contate: technova.sti@outlook.com.

Contato
Para suporte ou mais informações, entre em contato pelo e-mail: technova.sti@outlook.com