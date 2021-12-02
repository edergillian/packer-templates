# Templating c/ Packer (para Rancher & Foreman)

Repositório para criação de templates no vSphere, usando Packer, para provisionamento de VM's usando Rancher e Foreman, com pipeline de CI/CD para automação do processo.

## Requisitos

* Packer
* Cluster vCenter e credenciais com acesso devido
* Foreman, integrado ao cluster vCenter

## Instalação do Packer

Para instalar o Packer, basta seguir as [instruções da documentação oficial](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli).

## Criação de Templates

Para criar os templates individualmente, usar as pastas sem **prod** no nome (ex.: ubuntu1804rancher ou ubuntu2004foreman). As pastas com **prod** no nome servem para clonar.

Antes de executar o comando de criação do template, é importante definir as variáveis de ambiente necessárias para a correta execução do Packer.

As variáveis utilizadas na construção estão definidas nos arquivos **variables.json** de cada pasta.

As variáveis de ambiente são:

* VCENTER_SERVER: servidor do vCenter onde as imagens serão criadas
* VCENTER_USER: usuário com as devidas permissões para criação de templates. Pode ser usado um administrador global para facilitar; caso queira restringir as permissões, consultar [a documentação do Packer para isso](https://www.packer.io/docs/builders/vsphere/vsphere-iso#required-vsphere-permissions)
* VCENTER_PASSWORD: senha do usuário
* VCENTER_DATACENTER: nome do datacenter do vCenter
* VCENTER_CLUSTER: nome do cluster dentro do datacenter
* VCENTER_NETWORK: nome da rede onde será criada a interface da VM
* VCENTER_DATASTORE: nome do datastore onde será armazenado o template
* VCENTER_FOLDER: nome da pasta onde será incluído o template
* TEMPLATE_NAME: nome do template

Uma vez que as variáveis de ambiente estejam definidas, basta entrar na pasta e executar o seguinte comando (é necessário que o Packer esteja instalado):

```
packer build -var-file variables.json build.json
```

## Automação da criação dos templates

Para automatizar o processo de criação dos templates, foi criado um pipeline de CI/CD para GitLab (.gitlab-ci.yml), no qual são executadas os seguintes estágios:

* deploy: criação dos templates em ambiente dev
* clone_to_prod: criação dos templates em ambiente prod (clone dos templates dev)
* update_foreman: atualização das imagens no Foreman (esse passo é necessário porque o Foreman associa as imagens aos templates através do UUID do disco ao invés do nome da VM; com isso, após a atualização do template, é necessário fazer nova associação, pois houve mudança do UUID. Como o Rancher faz a associação das imagens com os templates a partir do nome, não é necessária qualquer intervenção neste ponto).

Para os 2 primeiros estágios, é necessário criar uma imagem Docker contendo Packer e Vault. [Nesse repositório](https://github.com/edergillian/hashicorp-tools-images) é possível encontrar um exemplo de como criar essa imagem.

Para o último estágio, é necessário criar uma imagem Docker contendo Hammer CLI. [Nesse repositório](https://github.com/edergillian/hammer-cli-image) é possível encontrar um exemplo de como criar essa imagem.

Uma vez criadas as imagens, elas devem substituir no .gitlab-ci.yml, respectivamente, os valores <<image_with_packer_and_vault>> e <<image_with_hammer_cli>>.

O template de script *.get_env_from_vault* é utilizado para se conectar ao Vault e ler as variáveis de ambiente a partir dele. Devem ser criados os respectivos secrets e o caminho deles deve substituir os valores path/to/vcenter/user e path/to/vcenter/password para usuário e senha do vCenter respectivamente. Pode ser utilizada a mesma lógica para incluir no Vault o valor do restante das variáveis de ambiente. 

Caso não tenha o Vault implementado ou não queira utilizá-lo para alguma das variáveis de ambiente, basta definí-las nas variáveis globais (ou nas variáveis de CI/CD do projeto). É importante ressaltar que o nome do template (VCENTER_VM_NAME) deve ser único e, portanto, deve ser definido no conjunto de variáveis de cada job do pipeline.

No último estágio, é importante definir as variáveis de ambiente FOREMAN_USER, FOREMAN_PASSWORD e FOREMAN_HOST. O job foi construído baseado na premissa de que há apenas um Compute Resource registrado no Foreman, cujo *id=1*. Se não for esse o caso, é necessário mudar o *id* para refletir o ambiente em questão (ou incluir uma lógica para obter esse valor com o hammer, conforme feito para as imagens e os templates).

Uma vez que o pipeline esteja configurado, basta agendá-lo no GitLab.