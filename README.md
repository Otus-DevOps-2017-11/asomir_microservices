# Homework-28
## Введение в Kubernetes
### Создание примитивов

Опишем приложение в контексте Kubernetes с помощью manifest-ов
в YAML-формате. Основным примитивом будет Deployment.

Основные задачи сущности Deployment:

• Создание Replication Controller-а (следит, чтобы число
запущенных Pod-ов соответствовало описанному)

• Ведение истории версий запущенных Pod-ов (для различных
стратегий деплоя, для возможностей отката)

• Описание процесса деплоя (стратегия, параметры стратегий)
По ходу курса эти манифесты будут обновляться, а также
появляться новые. Текущие файлы нужны для создания структуры и
проверки работоспособности kubernetes-кластера.

##### Пример манифеста для Deployment POST-компоненты

```yamlex
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: post-deployment
spec:
  replicas: 1
  selector:
    matchLabels: # Какие поды поддерживать в нужном количестве
      app: post
  template:
    metadata:
      name: post
      labels:
        app: post
    spec:
      containers:
      - image: asomir/post # Метка, чтобы Replication controller нашел под
        name: post
```

### Задание

• Создайте папку kubernetes в корне репозитория

• Сохраните файл post-deployment.yml в папку kubernetes


P.S. Эту папку и файлы в ней в дальнейшем мы будем развивать (пока это
не рабочие экземпляры)

### Kubernetes the hard way

#### Labs

###### Пометка

В этом руководстве предполагается, что у нас есть доступ к Облачной платформе Google. Хотя GCP используется для базовых требований к инфраструктуре, уроки, извлеченные в этом руководстве, могут быть применены к другим платформам.

##### Первым делом проверим, что у нас с ГуглоКлаудом

```bash
gcloud version
gcloud init
gcloud config set compute/region us-west1
# По умолчанию используем зону us-west1-c
gcloud config set compute/zone us-west1-c
```
#### Устанавливаем клиентские тулзы

##### Утилиты командной строки cfssl и cfssljson будут использоваться для предоставления инфраструктуры PKI и создания сертификатов TLS.

Загружаем и устанавливаем cfssl и cfssljson из репозитория cfssl:

```bash
wget -q --show-progress --https-only --timestamping \
  https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
  https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
```
```bash
chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```
Проверяем:

```bash
cfssl version
```

> output

```markdown
Version: 1.2.0
Revision: dev
Runtime: go1.6

```

#### Устанавливаем kubectl

##### Утилита командной строки kubectl используется для взаимодействия с сервером API Kubernetes. Загружаем и устанавливаем kubectl из официальных релизов:


```bash
wget https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

##### Проверяем: 

```bash
kubectl version --client
```
> output

```markdown
Client Version: version.Info{Major:"1", Minor:"10", GitVersion:"v1.10.0", GitCommit:"fc32d2f3698e36b93322a3465f63a14e9f0eaead", GitTreeState:"clean", BuildDate:"2018-03-26T16:55:54Z", GoVersion:"go1.9.3", Compiler:"gc", Platform:"linux/amd64"}

```

#### Provisioning 


Kubernetes требуется набор машин для размещения системы управления Kubernetes и рабочих узлов, где в конечном итоге выполняются контейнеры.
В этой лаборатории мы предоставим вычислительные ресурсы, необходимые для работы безопасного и высокодоступного кластера Kubernetes в одной вычислительной зоне.


#### Networking

Сетевая модель Kubernetes представляет собой сеть, в которой контейнеры и узлы могут взаимодействовать друг с другом. 
В случаях, когда это нежелательно, сетевые политики могут ограничивать взаимодействие групп контейнеров между собой и внешними конечными точками сети.

#### Virtual Private Cloud Network

В этом разделе будет настроена выделенная сеть виртуального частного облака (VPC) для размещения кластера Kubernetes.

##### Создадим виртуальную сеть VPC kubernetes-the-hard-way

```bash
gcloud compute networks create kubernetes-the-hard-way --subnet-mode custom
```

> output

```markdown
Created [https://www.googleapis.com/compute/v1/projects/docker-194414/global/networks/kubernetes-the-hard-way].
NAME                     SUBNET_MODE  BGP_ROUTING_MODE  IPV4_RANGE  GATEWAY_IPV4
kubernetes-the-hard-way  CUSTOM       REGIONAL

Instances on this network will not be reachable until firewall rules
are created. As an example, you can allow all internal traffic between
instances as well as SSH, RDP, and ICMP by running:

$ gcloud compute firewall-rules create <FIREWALL_NAME> --network kubernetes-the-hard-way --allow tcp,udp,icmp --source-ranges <IP_RANGE>
$ gcloud compute firewall-rules create <FIREWALL_NAME> --network kubernetes-the-hard-way --allow tcp:22,tcp:3389,icmp

```


##### Создадим подсеть kubernetes в сети VPC kubernetes-hard-way:

Подсеть должна быть снабжена диапазоном IP-адресов, достаточно большим для назначения частного IP-адреса каждому узлу кластера Kubernetes


```bash
gcloud compute networks subnets create kubernetes \
  --network kubernetes-the-hard-way \
  --range 10.240.0.0/24
```
> output

```markdown
Created [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/subnetworks/kubernetes].
NAME        REGION        NETWORK                  RANGE
kubernetes  europe-west1  kubernetes-the-hard-way  10.240.0.0/24

```
### Firewall Rules

##### Создадим правило межсетевого экрана, которое позволяет внутреннюю связь по всем протоколам:

```bash
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 10.240.0.0/24,10.200.0.0/16  
```
> output

```markdown
Creating firewall...-Created [https://www.googleapis.com/compute/v1/projects/docker-194414/global/firewalls/kubernetes-the-hard-way-allow-internal].                                                        
Creating firewall...done.                                                                                                                                                                                   
NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW         DENY
kubernetes-the-hard-way-allow-internal  kubernetes-the-hard-way  INGRESS    1000      tcp,udp,icmp
```

##### А также правило брандмауэра, которое позволяет использовать внешние SSH, ICMP и HTTPS:

```bash
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-the-hard-way \
  --source-ranges 0.0.0.0/0
```
> output

```markdown
Creating firewall.../Created [https://www.googleapis.com/compute/v1/projects/docker-194414/global/firewalls/kubernetes-the-hard-way-allow-external].                                                        
Creating firewall...done.                                                                                                                                                                                   
NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW                 DENY
kubernetes-the-hard-way-allow-external  kubernetes-the-hard-way  INGRESS    1000      tcp:22,tcp:6443,icmp
```

> Для публикации серверов API Kubernetes для удаленных клиентов будет использоваться внешний балансировщик нагрузки
https://cloud.google.com/compute/docs/load-balancing/network/

##### Внесём kubernetes-hard-way в правила брандмауэра сети VPC:

```bash
gcloud compute firewall-rules list --filter="network:kubernetes-the-hard-way"
```

> output

```markdown
NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW                 DENY
kubernetes-the-hard-way-allow-external  kubernetes-the-hard-way  INGRESS    1000      tcp:22,tcp:6443,icmp
kubernetes-the-hard-way-allow-internal  kubernetes-the-hard-way  INGRESS    1000      tcp,udp,icmp

```

#### Kubernetes Public IP Address


##### Выделяем статический IP-адрес, который будет подключен к внешнему балансировщику нагрузки, выходящему на серверы API Kubernetes:

```bash
gcloud compute addresses create kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region)
```
> output

```markdown
ERROR: (gcloud.compute.addresses.create) Could not fetch resource:
 - Quota 'STATIC_ADDRESSES' exceeded. Limit: 1.0 in region europe-west1.
```
Количество внешних IP для нашего типа аккаунта ограничено 1 штукой. Поэтому лезем в GCP и удаляем айпи, которые мы биндили в предыдущих лабораторках.

##### Пробуем снова, получаем: 

> output

```markdown
Created [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/addresses/kubernetes-the-hard-way].
```
##### Проверяем, что статический IP был создан для нашего региона по умолчанию: 

```bash
gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"
```
> output

```markdown
NAME                     REGION        ADDRESS       STATUS
kubernetes-the-hard-way  europe-west1  35.187.10.59  RESERVED
```

### Создаём инстансы

Все инстансы в этой лаборатории будут созданы с использованием Ubuntu Server 16.04, 
который имеет хорошую поддержку для среды выполнения cri-containerd. 
Каждому инстансу будет предоставлен фиксированный частный IP-адрес, чтобы упростить процесс начальной загрузки Kubernetes.

#### Kubernetes Controllers

##### Создадим три инстанса, которые будут хоститься в панели управления Kubernetes

```bash
for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1604-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done
```
> output

```markdown
Instance creation in progress for [controller-0]: https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/operations/operation-1522503320869-568b56d9c1888-56a1a189-ceb18ad6
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [controller-1]: https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/operations/operation-1522503323503-568b56dc4499a-c5e8290b-1790c867
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [controller-2]: https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/operations/operation-1522503326381-568b56df033c9-7db19b94-84ad790d
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
```
#### Kubernetes Workers

##### Заметка 

Каждому инстансу требуется подсеть pod-а  расположенного в диапазоне CIDR кластера Kubernetes. 
Распределение подсети pod-а будет использоваться для конфигурирования сетей контейнеров в последующих упражнениях. 
Метаданные экземпляра pod-cidr будут использоваться для выделения подсетей pod-ов для создания инстансов во время выполнения

> Диапазон CIDR кластера Kubernetes определяется флажком -cluster-cidr диспетчера контроллера.
В этом уроке диапазон CIDR кластера будет установлен в 10.200.0.0/16, который поддерживает 254 подсети.

##### Создадим три хоста, на которых будут размещены воркер ноды Kubernetes:

```bash
for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1604-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --metadata pod-cidr=10.200.${i}.0/24 \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,worker
done
```
> output

```markdown
Instance creation in progress for [worker-0]: https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/operations/operation-1522504024458-568b5978c0310-0c1f951e-cd142a49
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [worker-1]: https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/operations/operation-1522504026910-568b597b16d30-2bf96c1f-12568b9d
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [worker-2]: https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/operations/operation-1522504029482-568b597d8ac13-1e2e4a88-ec8784f3
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
```

#### Проверка

##### Список инстансов в нашей зоне по умолчанию: 

```bash
gcloud compute instances list
```
> output

```markdown
NAME          ZONE            MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
controller-0  europe-west1-c  n1-standard-1               10.240.0.10  35.189.220.78   RUNNING
controller-1  europe-west1-c  n1-standard-1               10.240.0.11  35.189.217.138  RUNNING
controller-2  europe-west1-c  n1-standard-1               10.240.0.12  35.187.86.197   RUNNING
worker-0      europe-west1-c  n1-standard-1               10.240.0.20  35.187.59.135   RUNNING
worker-1      europe-west1-c  n1-standard-1               10.240.0.21  35.187.103.138  RUNNING
worker-2      europe-west1-c  n1-standard-1               10.240.0.22  35.187.80.110   RUNNING
```

### Provisioning a CA and Generating TLS Certificates

В этой лаборатории мы развернём инфраструктуру PKI с помощью инструментария CloudFlare PKI - cfssl, -
затем используем его для загрузки центра сертификации и создания сертификатов TLS для следующих компонентов: 
etcd, kube-apiserver, kubelet и kube-proxy.

#### Certificate Authority

В этой секции мы развернём центр Сертификации, который будет использоваться для создания добавочных TLS сертификатов.

##### Создадим конфигурационный файл СА

```bash
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```
##### Создаём СА сертификат запроса подписи: 

```bash
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF
```
##### Создаём СА сертификат и приватный ключ: 

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```
> output

```markdown
2018/03/31 17:20:29 [INFO] generating a new CA key and certificate from CSR
2018/03/31 17:20:29 [INFO] generate received request
2018/03/31 17:20:29 [INFO] received CSR
2018/03/31 17:20:29 [INFO] generating key: rsa-2048
2018/03/31 17:20:29 [INFO] encoded CSR
2018/03/31 17:20:29 [INFO] signed certificate with serial number 517291740959154520333108998637393139077620375351
```

> Result: 
ca-key.pem
ca.pem

#### Сертификаты Клиента и Сервера

В этой секции мы создадим клиентские и серверные сертификаты для каждого компонента Kubernetes и клиентский сертификат для пользователя admin Kubernetes

##### Создадим клиенсткий сертификат запроса пользователя admin: 

```bash
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
```
##### Создаём клиентский сертификат пользователя admin и приватный ключ: 

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
```
> output

```markdown
2018/03/31 17:27:23 [INFO] generate received request
2018/03/31 17:27:23 [INFO] received CSR
2018/03/31 17:27:23 [INFO] generating key: rsa-2048
2018/03/31 17:27:24 [INFO] encoded CSR
2018/03/31 17:27:24 [INFO] signed certificate with serial number 220955992656473698065928498566533380880979756528
2018/03/31 17:27:24 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
```
> Results:
admin-key.pem
admin.pem

#### Клиентские сертификаты Kubelet

Kubernetes использует специальный режим авторизации, называемый Node Authorizer, который разрешает запросы API, сделанные Kubelets.
Чтобы авторизоваться d Node Authorizer, Kubelets должен использовать учетные данные, которые идентифицируются как system:nodes с именем system:node:<nodeName>

В этом разделе мы создадим сертификат для каждого рабочего узла Kubernetes, который удовлетворяет требованиям Node Authorizer.

##### Создаём сертификат и приватный ключ для каждой воркер ноды Кубернетеса: 

```bash
for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

EXTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

INTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].networkIP)')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done
```

> output

```markdown
2018/03/31 17:37:14 [INFO] generate received request
2018/03/31 17:37:14 [INFO] received CSR
2018/03/31 17:37:14 [INFO] generating key: rsa-2048
2018/03/31 17:37:14 [INFO] encoded CSR
2018/03/31 17:37:14 [INFO] signed certificate with serial number 629311987656347244410150681752434259976665356492
2018/03/31 17:37:16 [INFO] generate received request
2018/03/31 17:37:16 [INFO] received CSR
2018/03/31 17:37:16 [INFO] generating key: rsa-2048
2018/03/31 17:37:17 [INFO] encoded CSR
2018/03/31 17:37:17 [INFO] signed certificate with serial number 80368820250113608803997366531865511194319866127
2018/03/31 17:37:19 [INFO] generate received request
2018/03/31 17:37:19 [INFO] received CSR
2018/03/31 17:37:19 [INFO] generating key: rsa-2048
2018/03/31 17:37:19 [INFO] encoded CSR
2018/03/31 17:37:19 [INFO] signed certificate with serial number 239596205710900482054871683117156784809169780486
```

> Results:

```markdown
worker-0-key.pem
worker-0.pem
worker-1-key.pem
worker-1.pem
worker-2-key.pem
worker-2.pem
```

##### Клиентский сертификат kube-proxy:

```bash
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
```

##### Генерируем клиентский сертификат и приватный ключ для kube-proxy:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
```

> output

```markdown
2018/03/31 17:40:36 [INFO] generate received request
2018/03/31 17:40:36 [INFO] received CSR
2018/03/31 17:40:36 [INFO] generating key: rsa-2048
2018/03/31 17:40:38 [INFO] encoded CSR
2018/03/31 17:40:38 [INFO] signed certificate with serial number 218230184839130505543500517665415013806362365235
2018/03/31 17:40:38 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
```

> Results:
kube-proxy-key.pem
kube-proxy.pem

##### Сертификат Kubernetes API Сервера

Статический IP адрес kubernetes-the-hard-way будет включён в список альтернативных имён для сертификата Kubernetes API сервера
Это гарантирует, что сертификат может быть проверен удаленными клиентами.

##### Извлечём статический IP адрес kubernetes-the-hard-way:

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
```

##### Создаём запрос подписи Kubernetes API Сервера: 

```bash
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
```

##### Генерируем сертификат и приватный ключ  Kubernetes API:


```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```

> output

```markdown
2018/03/31 17:49:13 [INFO] generate received request
2018/03/31 17:49:13 [INFO] received CSR
2018/03/31 17:49:13 [INFO] generating key: rsa-2048
2018/03/31 17:49:13 [INFO] encoded CSR
2018/03/31 17:49:13 [INFO] signed certificate with serial number 2407003850554333109408762868611535053182373882
```

> Results:
kubernetes-key.pem
kubernetes.pem

#### Распределяем сертификаты клиента и сервера: 

##### Копируем соответствующие сертификаты и закрытые ключи для каждого воркера: 

```bash
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done
```
> output

```markdown
WARNING: The public SSH key file for gcloud does not exist.
WARNING: The private SSH key file for gcloud does not exist.
WARNING: You do not have an SSH key for gcloud.
WARNING: SSH keygen will be executed to generate a key.
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/asomir/.ssh/google_compute_engine.
Your public key has been saved in /home/asomir/.ssh/google_compute_engine.pub.
The key fingerprint is:
SHA256:CW16CJYLpYSxLHi4CHN+yz0eV7CJL8uhgN1D5s8tLrI asomir@asomir-ubuntu
The key's randomart image is:
+---[RSA 2048]----+
|.o. .            |
|++ o . .         |
|B.= + . +        |
|+* o o * =       |
|o . = + S .      |
| o B o o .       |
|. o * * o        |
|  ...B.O         |
|  Eo.oB..        |
+----[SHA256]-----+
Updating project ssh metadata...|Updated [https://www.googleapis.com/compute/v1/projects/docker-194414].                                                                                                    
Updating project ssh metadata...done.                                                                                                                                                                       
Waiting for SSH key to propagate.
Warning: Permanently added 'compute.8850945318776352695' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                     100% 1367     1.3KB/s   00:00    
worker-0-key.pem                                                                                                                                                           100% 1679     1.6KB/s   00:00    
worker-0.pem                                                                                                                                                               100% 1493     1.5KB/s   00:00    
Warning: Permanently added 'compute.3991824877216739252' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                     100% 1367     1.3KB/s   00:00    
worker-1-key.pem                                                                                                                                                           100% 1675     1.6KB/s   00:00    
worker-1.pem                                                                                                                                                               100% 1493     1.5KB/s   00:00    
Warning: Permanently added 'compute.23582907428908978' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                     100% 1367     1.3KB/s   00:00    
worker-2-key.pem                                                                                                                                                           100% 1675     1.6KB/s   00:00    
worker-2.pem                                                                                                                                                               100% 1493     1.5KB/s   00:00  
```

##### Копируем соответствующие сертификаты и закрытые ключи для каждого экземпляра инстанса:

```bash
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem ${instance}:~/
done
```
> output

```markdown
Warning: Permanently added 'compute.1748940011183681654' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                     100% 1367     1.3KB/s   00:00    
ca-key.pem                                                                                                                                                                 100% 1675     1.6KB/s   00:00    
kubernetes-key.pem                                                                                                                                                         100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                                                                             100% 1521     1.5KB/s   00:00    
Warning: Permanently added 'compute.1910890222754869364' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                     100% 1367     1.3KB/s   00:00    
ca-key.pem                                                                                                                                                                 100% 1675     1.6KB/s   00:00    
kubernetes-key.pem                                                                                                                                                         100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                                                                             100% 1521     1.5KB/s   00:00    
Warning: Permanently added 'compute.1826529724962320497' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                     100% 1367     1.3KB/s   00:00    
ca-key.pem                                                                                                                                                                 100% 1675     1.6KB/s   00:00    
kubernetes-key.pem                                                                                                                                                         100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                                                                             100% 1521     1.5KB/s   00:00    
```

### Генерация конфигурационных файлов для аутентификации Кубернетеса

В этой лабе мы сгенерируем  Kubernetes configuration files, также известные как kubeconfigs, 
которые позволяют клиентам Kubernetes находить и проверять подлинность на серверах API Kubernetes

#### Client Authentication Configs

В этом разделе мы создадим файлы kubeconfig для клиентов kubelet и kube-proxy.

##### Пометка

```markdown
scheduler и controller manager получают доступ к серверу API Kubernetes локально через небезопасный порт API, который не требует аутентификации. 
Небезопасный порт сервера Kubernetes API доступен только для локального доступа.
```

#### Kubernetes Public IP Address

Для каждого kubeconfig требуется подключение к серверу API Kubernetes. Для обеспечения высокой доступности будет использоваться IP-адрес,
назначенный внешнему балансировщику нагрузки, выходящему на серверы API Kubernetes.

##### Извлекаем kubernetes-the-hard-way static IP address:

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
```

#### The kubelet Kubernetes Configuration File

При создании файлов kubeconfig для Kubelets должен использоваться сертификат клиента, соответствующий имени узла Kubelet.
Это обеспечит правильное разрешение Kubelets авторизованным узлом Kubernetes Node

##### Создаём файл kubeconfig для каждого рабочего узла:

```bash
for instance in worker-0 worker-1 worker-2; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
```
> output

```markdown
Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-0" set.
Context "default" created.
Switched to context "default".
Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-1" set.
Context "default" created.
Switched to context "default".
Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-2" set.
Context "default" created.
Switched to context "default".
```

> Results:
worker-0.kubeconfig
worker-1.kubeconfig
worker-2.kubeconfig

#### The kube-proxy Kubernetes Configuration File

##### Создаём файл kubeconfig для службы kube-proxy:

```bash
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig
```

> output

```markdown
Cluster "kubernetes-the-hard-way" set.
```

```bash
kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
```
> output

```markdown
User "kube-proxy" set.
```
```bash
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
```
> output

```markdown
Context "default" created.
```

```bash
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```
> output

```markdown
Switched to context "default".
```

#### Распределяем файлы конфигурации Кубернетиса:

##### Копируем соответствующие файлы kubeec и kube-proxy kubeconfig в каждый инстанс воркер:

```bash
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done
```
> output 

```markdown
worker-0.kubeconfig                                                                                                                                                        100% 6450     6.3KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                                      100% 6374     6.2KB/s   00:00    
worker-1.kubeconfig                                                                                                                                                        100% 6446     6.3KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                                      100% 6374     6.2KB/s   00:00    
worker-2.kubeconfig                                                                                                                                                        100% 6446     6.3KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                                      100% 6374     6.2KB/s   00:00    
```


### Создание конфигурации и ключа шифрования данных


Kubernetes хранит множество данных, включая состояние кластера, конфигурации приложений и секреты. 
Kubernetes поддерживает возможность шифрования данных кластера в покое.

В этой секции мы создадим ключ шифрования и конфигурацию шифрования, подходящую для шифрования Kubernetes Secrets.

#### The Encryption Key (Ключ шифрования)

##### Создаём ключ шифрования: 

```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```
#### Файл конфигурации шифрования

##### Создаём файл конфигурации шифрования encryption-config.yaml:

```bash
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

##### Скопируйте файл конфигурации шифрования encryption-config.yaml в каждый экземпляр контроллера:

```bash
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp encryption-config.yaml ${instance}:~/
done
```
> output

```markdown
encryption-config.yaml                                                                                                                                                     100%  240     0.2KB/s   00:00    
encryption-config.yaml                                                                                                                                                     100%  240     0.2KB/s   00:00    
encryption-config.yaml                                                                                                                                                     100%  240     0.2KB/s   00:00    
```

### Bootstrapping the etcd Cluster

Компоненты Kubernetes не имеют состояния и сохраняют состояние кластера в etcd. 
В этой секции мы загрузим кластер с тремя узлами и т.д. и настроим его для обеспечения высокой доступности и безопасного удаленного доступа.

#### Prerequisites

Команды в этой лаборатории должны запускаться на каждом экземпляре контроллера: controller-0, controller-1, и controller-2.  
##### 1. Войдём в каждый экземпляр контроллера, используя команду gcloud. Пример:

```bash
gcloud compute ssh controller-0
```
#### Bootstrapping на etcd Cluster Member

##### 2. Загрузка и инсталляция etcd Binaries. Скачиваем официальный релиз etcd 
https://github.com/coreos/etcd

```bash
wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz"
```
##### 3. Извлекаем и устанавливаем сервер etcd и утилиту командной строки etcdctl:

```bash
tar -xvf etcd-v3.2.11-linux-amd64.tar.gz
```
```bash
sudo mv etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
```

#### 4. Конфигурируем etcd Server

```bash
sudo mkdir -p /etc/etcd /var/lib/etcd
```
```bash
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```
##### 5. Внутренний IP-адрес экземпляра будет использоваться для обслуживания клиентских запросов и обмена данными с etcd cluster peers. 
##### Получаем внутренний IP-адрес для текущего экземпляра инстанса:

```bash
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
```
##### 6. Каждый член etcd должен иметь уникальное имя в кластере etcd. Зададим имя etcd для соответствия имени хоста текущего инстанса:

```bash
ETCD_NAME=$(hostname -s)
```
##### 7. Создаём файл unitd.service systemd:


```bash
cat > etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```
##### 8. Стартуем etcd Server:


```bash
sudo mv etcd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable etcd
```
> output

```markdown
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /etc/systemd/system/etcd.service.
```
```bash
sudo systemctl start etcd
```

##### 9. Не забываем запустить приведенные выше команды 1-9 на каждом узле контроллера: controller-0, controller-1 и controller-2.

```bash
gcloud compute ssh controller-1
gcloud compute ssh controller-2
```
##### Проверяем. Список членов кластера etcd:

```bash
ETCDCTL_API=3 etcdctl member list
```

> output
```markdown
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:2379
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:2379
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:2379
```


### Bootstrapping the Kubernetes Control Plane


В этой секции вы загрузите слой управления Kubernetes на три инстанса и настроите его для обеспечения высокой доступности. 
Вы также создадите внешний балансировщик нагрузки, который предоставляет серверу API Kubernetes для удаленных клиентов. 
На каждом узле будут установлены следующие компоненты: Kubernetes API Server, Scheduler и Controller Manager.

#### Prerequisites

##### Команды в этой секции необходимо запускать на всех инстансах по очереди: controller-0, controller-1 и controller-2. 
##### 1. Логинимся через SSH на каждый инстанс: 

```bash
gcloud compute ssh controller-0
```
#### Провижен управляющего плана Kubernetes
##### 2. Загрузка и установка официальных бинарников контроллера Kubernetes. Загружаем с официальных реп: 

```bash
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl"
```
##### 3. Устанавливаем скаченные бинарники: 

```bash
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
```
##### 4. Конфигурирование Kubernetes API сервера

```bash
sudo mkdir -p /var/lib/kubernetes/
sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem encryption-config.yaml /var/lib/kubernetes/
```
##### 5. Внутренний IP-адрес инстанса будет использоваться для обращения сервера API к членам кластера. Получим внутренний IP-адрес для текущего инстанса:

```bash
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
```

##### 6. Создаём файл юнита kube-apiserver.service systemd:

```bash
cat > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --insecure-bind-address=127.0.0.1 \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/ca-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-ca-file=/var/lib/kubernetes/ca.pem \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Конфигурируем контроль менеджера Кубернетеса: 

##### 7. Создаём файл юнита kube-controller-manager.service systemd:

```bash
cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```
#### Конфигурирование планировщика Кубернетиса:

##### 8. Создаём файл юнита kube-scheduler.service systemd:

```bash
cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

##### 9. Стартуем сервисы контроллера: 

```bash
sudo mv kube-apiserver.service kube-scheduler.service kube-controller-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
```

> output 

```markdown
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-apiserver.service to /etc/systemd/system/kube-apiserver.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service to /etc/systemd/system/kube-controller-manager.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-scheduler.service to /etc/systemd/system/kube-scheduler.service.

```
##### 10. Ждём инициализации сервера API Kubernetes 10 секунд. Проверяем: 

```bash
kubectl get componentstatuses
```

```markdown
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-1               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
```
##### 11. Не забываем всё то же самое (1-10) выполнить на всех контроллерах нод: controller-0, controller-1 и controller-2.

#### RBAC for Kubelet Authorization

В этом разделе мы будем настраивать разрешения RBAC, чтобы позволить серверу API Kubernetes обращаться к API-интерфейсу Kubelet на каждом воркере. 
Доступ к API Kubelet необходим для получения метрик, журналов и выполнения команд в контейнерах.

> Этот учебник устанавливает флаг Kubelet -authorization-mode в Webhook. Режим Webhook использует API SubjectAccessReview для определения авторизации.

````bash
gcloud compute ssh controller-0
````

##### 1. Создаём system:kube-apiserver-to-kubelet ClusterRole с разрешениями доступа к API Kubelet и выполнением большинства обычных задач, связанных с управлением подами:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```
> output
```markdown
clusterrole "system:kube-apiserver-to-kubelet" created
```
Сервер API Kubernetes аутентифицируется на Kubelet как пользователь kubernetes, используя сертификат клиента, 
как определено флажком --kubelet-client-certificate.

##### 2. Привяжем system:kube-apiserver-to-kubelet ClusterRole к пользователю kubernetes:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```
> output

```markdown
clusterrolebinding "system:kube-apiserver" created
```

#### Фронтэнд балансировщик нагрузки (The Kubernetes Frontend Load Balancer).

В этом разделе мы раскатаем внешний балансировщик нагрузки перед серверами API Kubernetes. 
К результирующему балансировщику нагрузки присоединяется статический IP-адрес kubernetes-the-hard-way. 

```markdown
Примечание: у созданных инстансов нет разрешений на выполнение команд этого раздела, поэтому команды выполняются с компьютера, с которого проводилось создание инстансов
```

```bash
gcloud compute target-pools create kubernetes-target-pool
```
> output

```markdown
Did you mean region [europe-west1] for target pool: 
[kubernetes-target-pool] (Y/n)?  y

Created [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/targetPools/kubernetes-target-pool].
NAME                    REGION        SESSION_AFFINITY  BACKUP  HEALTH_CHECKS
kubernetes-target-pool  europe-west1  NONE
```
```bash
gcloud compute target-pools add-instances kubernetes-target-pool \
  --instances controller-0,controller-1,controller-2
```
> output

```markdown
Did you mean zone [europe-west1-c] for instance: [controller-0, 
controller-1, controller-2] (Y/n)?  y

Updated [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/targetPools/kubernetes-target-pool].
```
````bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(name)')
````

```bash
gcloud compute forwarding-rules create kubernetes-forwarding-rule \
  --address ${KUBERNETES_PUBLIC_ADDRESS} \
  --ports 6443 \
  --region $(gcloud config get-value compute/region) \
  --target-pool kubernetes-target-pool
```

> output

```markdown
Created [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/forwardingRules/kubernetes-forwarding-rule].
```

#### Проверка: 

##### Извлекаем статический IP адрес kubernetes-the-hard-way:

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
```

##### Делаем HTTP реквест на запрос версии Kubernetes:

```bash
curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
```
> output

```markdown
{
  "major": "1",
  "minor": "9",
  "gitVersion": "v1.9.0",
  "gitCommit": "925c127ec6b946659ad0fd596fa959be43f0cc05",
  "gitTreeState": "clean",
  "buildDate": "2017-12-15T20:55:30Z",
  "goVersion": "go1.9.2",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```

### Развёртывание воркер нодов Кубернетиса (Bootstrapping the Kubernetes Worker Nodes)

В этой секции мы развернём три воркер ноды Кубернетиса. Следующие компоненты должны быть установлены на каждой ноде: 

 - runc, - является инструментом CLI для генерации и запуска контейнеров в соответствии со спецификацией OCI. https://github.com/opencontainers/runc
 
 - container networking plugins, - проект, состоит из спецификации и библиотек для написания плагинов для настройки сетевых интерфейсов в контейнерах Linux, 
   а также ряда поддерживаемых плагинов. CNI относится только к сетевому подключению контейнеров и удалению выделенных ресурсов при удалении контейнера.
   CNI имеет широкий диапазон поддержки, и спецификация проста в реализации. https://github.com/containernetworking/cni
   
 - cri-containerd, https://github.com/containerd/cri
 
 - kubelet, https://kubernetes.io/docs/reference/generated/kubelet/ - Кубелет является основным «агентом узла», который выполняется на каждом узле. Кубе работает с точки зрения PodSpec. 
   PodSpec - объект YAML или JSON, который описывает модуль. Kubelet принимает набор PodSpec, которые предоставляются через различные механизмы 
   (в первую очередь через apiserver) и гарантирует, что контейнеры, описанные в этих PodSpec, работают и здоровы. 
   Кубелет не управляет контейнерами, которые не были созданы Кубернетом. 
   Помимо того, что из PodSpec от apirusver существует три способа, чтобы контейнерный манифест мог быть предоставлен Kubelet.
    
    - Файл: Путь передан как флаг в командной строке. Файлы под этим путем будут периодически проверяться на наличие обновлений. 
     Период мониторинга по умолчанию равен 20 с и настраивается с помощью флага.
      
    - Конечная точка HTTP: конечная точка HTTP передается как параметр в командной строке. 
      Эта конечная точка проверяется каждые 20 секунд (также настраивается с помощью флага). 
      
    - HTTP-сервер: кубелет также может прослушивать HTTP и отвечать на простой API (underspec'd в настоящее время), чтобы отправить новый манифест.
 
 - kube-proxy. - https://kubernetes.io/docs/concepts/cluster-administration/proxies/
 
 
#### Важно

Команды в этой секции должны быть выполнены на всех воркерах: worker-0, worker-1 и worker-2. Войдите в каждый рабочий экземпляр, используя команду gcloud:

```bash
gcloud compute ssh worker-0
```

#### Provisioning a Kubernetes Worker Node

##### 1. Устанавливаем зависимости ОС:

```bash
sudo apt-get -y install socat
```
> Бинарный файл socat поддерживает поддержку команды kubectl port-forward.

##### 2. Загружаем и устанавливаем бинарники в воркере: 

```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
  https://github.com/containerd/cri-containerd/releases/download/v1.0.0-beta.1/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet
```
##### 3. Создаём необходимые папки для инсталяций: 

```bash
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

##### 4. Устанавливаем бинарники в воркерах: 

```bash
sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
sudo tar -xvf cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz -C /
chmod +x kubectl kube-proxy kubelet
sudo mv kubectl kube-proxy kubelet /usr/local/bin/
```
##### 4. Настройка сети CNI. Получим диапазон CIDR для текущего инстанса:

```bash
POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)
```

##### 5. Создадим файл конфигурации сети моста:

```bash
cat > 10-bridge.conf <<EOF
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```
##### 6. Создадим файл конфигурации сетевой петли:

```bash
cat > 99-loopback.conf <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

##### 7. Переместим файлы конфигурации сети в каталог конфигурации CNI:


```bash
sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
```
##### 8. Настройка Kubelet

````bash
sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo mv ca.pem /var/lib/kubernetes/
````
##### 9. Создаём файл блока kubelet.service systemd:

```bash
cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=cri-containerd.service
Requires=cri-containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --anonymous-auth=false \\
  --authorization-mode=Webhook \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --cloud-provider= \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/cri-containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --runtime-request-timeout=15m \\
  --tls-cert-file=/var/lib/kubelet/${HOSTNAME}.pem \\
  --tls-private-key-file=/var/lib/kubelet/${HOSTNAME}-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```
##### 10. Настройка прокси-сервера Kubernetes

```bash
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```
##### 11. Создаём файл блока kube-proxy.service systemd:

```bash
cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.200.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```
##### 12. Стартуем сервисы Воркера: 

````bash
sudo mv kubelet.service kube-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable containerd cri-containerd kubelet kube-proxy
sudo systemctl start containerd cri-containerd kubelet kube-proxy
````

##### Проверяем. Заходим на любой контроллер: 

```bash
gcloud compute ssh controller-0
```

```bash
kubectl get nodes
```
> output

```markdown
NAME       STATUS    ROLES     AGE       VERSION
worker-0   Ready     <none>    12m       v1.9.0
worker-1   Ready     <none>    5m        v1.9.0
worker-2   Ready     <none>    24s       v1.9.0

```
### Настройка kubectl для удаленного доступа

В этой лаборатории мы создадим файл kubeconfig для утилиты командной строки kubectl на основе учетных данных пользователя admin.

> Запустите команды в этой лаборатории из того же каталога, который используется для создания сертификатов клиента admin.

#### Файл конфигурации администратора Kubernetes

##### Для каждого kubeconfig требуется подключение к серверу API Kubernetes. Для обеспечения высокой доступности будет использоваться IP-адрес, назначенный внешнему балансировщику нагрузки, выходящему на серверы API Kubernetes.

##### Запросим внешний айпи kubernetes-the-hard-way

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')
```
##### Создадим файл kubeconfig, подходящий для аутентификации в качестве пользователя admin:

```bash
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443
```

```bash
kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem
```

```bash
kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin
```
```bash
kubectl config use-context kubernetes-the-hard-way
```

##### Проверьте работоспособность удаленного кластера Kubernetes:

```bash
kubectl get componentstatuses
```
> output: 

```markdown
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-2               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
```
##### Список узлов удаленного кластера Kubernetes:

```bash
kubectl get nodes
```
```markdown
NAME       STATUS    ROLES     AGE       VERSION
worker-0   Ready     <none>    26m       v1.9.0
worker-1   Ready     <none>    19m       v1.9.0
worker-2   Ready     <none>    14m       v1.9.0
```

### Провижининг маршрутизации сетей подов (Provisioning Pod Network Routes)

##### Заметка

> Поды, прикреплённые к ноде, получают IP-адрес из диапазона CIDR узла. В этот момент поды не могут взаимодействовать с другими модулями, запущенными на разных узлах из-за отсутствия сетевых маршрутов.
https://cloud.google.com/vpc/docs/routes

> Существуют и другие способы реализации сетевой модели Kubernetes:
https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this

#### Таблица маршрутизации

В этой секции мы соберём информацию, необходимую для создания маршрутов в сети VPC kubernetes-hard-way

##### Вытащим внутренний IP-адрес и диапазон CIDR для каждого воркер инстанса:


```bash
for instance in worker-0 worker-1 worker-2; do
  gcloud compute instances describe ${instance} \
    --format 'value[separator=" "](networkInterfaces[0].networkIP,metadata.items[0].value)'
done
```
> output

```markdown
10.240.0.20 10.200.0.0/24
10.240.0.21 10.200.1.0/24
10.240.0.22 10.200.2.0/24
```

#### Маршруты

##### Создадим маршруты сети для каждого инстанса воркера: 

```bash
for i in 0 1 2; do
  gcloud compute routes create kubernetes-route-10-200-${i}-0-24 \
    --network kubernetes-the-hard-way \
    --next-hop-address 10.240.0.2${i} \
    --destination-range 10.200.${i}.0/24
done
``` 
> output

```markdown
Created [https://www.googleapis.com/compute/v1/projects/docker-194414/global/routes/kubernetes-route-10-200-0-0-24].
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP     PRIORITY
kubernetes-route-10-200-0-0-24  kubernetes-the-hard-way  10.200.0.0/24  10.240.0.20  1000
Created [https://www.googleapis.com/compute/v1/projects/docker-194414/global/routes/kubernetes-route-10-200-1-0-24].
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP     PRIORITY
kubernetes-route-10-200-1-0-24  kubernetes-the-hard-way  10.200.1.0/24  10.240.0.21  1000
Created [https://www.googleapis.com/compute/v1/projects/docker-194414/global/routes/kubernetes-route-10-200-2-0-24].
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP     PRIORITY
kubernetes-route-10-200-2-0-24  kubernetes-the-hard-way  10.200.2.0/24  10.240.0.22  1000
```

##### Перечислим маршруты в сети VPC kubernetes-hard-way:

```bash
gcloud compute routes list --filter "network: kubernetes-the-hard-way"
```

>output

```markdown
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP                  PRIORITY
default-route-da909e003b938066  kubernetes-the-hard-way  0.0.0.0/0      default-internet-gateway  1000
default-route-ecc9970c8775d9fb  kubernetes-the-hard-way  10.240.0.0/24                            1000
kubernetes-route-10-200-0-0-24  kubernetes-the-hard-way  10.200.0.0/24  10.240.0.20               1000
kubernetes-route-10-200-1-0-24  kubernetes-the-hard-way  10.200.1.0/24  10.240.0.21               1000
kubernetes-route-10-200-2-0-24  kubernetes-the-hard-way  10.200.2.0/24  10.240.0.22               1000
```
### Развертывание дополнения кластера DNS

##### Развернём аддон кластера kube-dns:

```bash
kubectl create -f https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml
```
> output

```markdown
service "kube-dns" created
serviceaccount "kube-dns" created
configmap "kube-dns" created
deployment.extensions "kube-dns" created
```

##### Перечислим контейнеры, созданные при развертывании kube-dns:

```bash
kubectl get pods -l k8s-app=kube-dns -n kube-system
```

> output

```markdown
NAME                        READY     STATUS    RESTARTS   AGE
kube-dns-6c857864fb-dvb5q   3/3       Running   0          1m
```

#### Проверка

##### Сделаем развертывание busybox:

```bash
kubectl run busybox --image=busybox --command -- sleep 3600
```
##### Выведем поды созданные приложением busybox:

```bash
kubectl get pods -l run=busybox
```

> output

```markdown
NAME                       READY     STATUS    RESTARTS   AGE
busybox-855686df5d-rz57s   1/1       Running   0          15s
```

##### Запросим полное имя модуля busybox:

```bash
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
```

##### Выполните поиск DNS для службы kubernetes внутри модуля busybox:

```bash
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

> output 

```markdown
Server:    10.32.0.10
Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local
```

### Smoke Test

В этой лаборатории мы выполним ряд задач, чтобы убедиться, что ваш кластер Kubernetes работает правильно.

#### Шифрование данных

В этом разделе вы проверите возможность шифрования секретных данных в покое.

##### Создадим общий секрет:

```bash
kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"
```
##### Выведем  hexdump секретности kubernetes-the-hard-way, хранящийся в etcd:

```bash
gcloud compute ssh controller-0 \
  --command "ETCDCTL_API=3 etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"
```
> output

```markdown
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
00000040  3a 76 31 3a 6b 65 79 31  3a 4f 61 3a 97 67 58 6e  |:v1:key1:Oa:.gXn|
00000050  ce a7 3c c8 01 7c 5c 45  2c 0b be b1 84 6e 0f 97  |..<..|\E,....n..|
00000060  bd 24 d2 f8 43 91 2d a3  ec ea d5 d8 e9 14 75 73  |.$..C.-.......us|
00000070  2b 8d 1f d1 12 a5 a3 a3  49 6a e3 43 0e 94 f8 fa  |+.......Ij.C....|
00000080  5a 1e 88 96 0a d6 22 2b  fc 77 6f 7a 62 c6 96 6b  |Z....."+.wozb..k|
00000090  0c 90 20 b9 73 72 82 d4  18 01 37 6d 23 de f6 8e  |.. .sr....7m#...|
000000a0  51 47 2c af dc 61 18 ec  ef 6d 80 5d 71 a5 9f 77  |QG,..a...m.]q..w|
000000b0  8b 02 3c da a6 d1 2d 3d  9a 46 ee 3d f6 77 2a 01  |..<...-=.F.=.w*.|
000000c0  d2 e6 83 e2 2b 84 48 2c  ef 45 53 91 6e 65 e7 a4  |....+.H,.ES.ne..|
000000d0  90 a3 0b 7b f9 d4 eb 2f  de 14 3a 4a 69 80 33 14  |...{.../..:Ji.3.|
000000e0  7f da 2a 11 92 9d 65 01  ca 0a                    |..*...e...|
000000ea
```

> Ключ etcd должен иметь префикс k8s: enc: aescbc: v1: key1, который указывает, что поставщик aescbc использовался для шифрования данных ключом ключа key1.

#### Развертывания

##### В этом разделе вы сможете проверить возможность создания и управления развертываниями. https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

##### Создадим развертывание для веб-сервера nginx: 

```bash
kubectl run nginx --image=nginx
```
##### Выведем под созданный при развёртывании nginx

```bash
kubectl get pods -l run=nginx
```
> output

```markdown
NAME                   READY     STATUS    RESTARTS   AGE
nginx-8586cf59-2z8qp   1/1       Running   0          58s
```

#### Перенаправление портов

##### В этом разделе вы будете проверять возможность удаленного доступа к приложениям с помощью переадресации портов.

##### Получим полное имя nginx pod:

```bash
POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")
```

##### Переместить порт 8080 на локальную машину на порт 80 модуля nginx:

```bash
kubectl port-forward $POD_NAME 8080:80
```
> output

```markdown
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
```

##### В новом терминале введёс HTTP-запрос, используя адрес пересылки:

````bash
curl --head http://127.0.0.1:8080
````
> output

```markdown
HTTP/1.1 200 OK
Server: nginx/1.13.10
Date: Sun, 01 Apr 2018 09:03:39 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 20 Mar 2018 10:03:54 GMT
Connection: keep-alive
ETag: "5ab0dc8a-264"
Accept-Ranges: bytes
```

##### Вернёмся к предыдущему терминалу и остановим пересылку порта в модуль nginx:

```markdown
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
Handling connection for 8080
^C
```

#### Logs

##### Выведем логи пода nginx:

```bash
kubectl logs $POD_NAME
``` 
> output
```markdown
127.0.0.1 - - [01/Apr/2018:09:03:39 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.47.0" "-"
```
#### Exec

##### Распечатайте версию nginx, выполнив команду nginx -v в контейнере nginx:

```bash
kubectl exec -ti $POD_NAME -- nginx -v
```
> output

```markdown
nginx version: nginx/1.13.10
```
#### Services

##### Выполните развертывание nginx с помощью службы NodePort:

```bash
kubectl expose deployment nginx --port 80 --type NodePort
```

> Тип службы LoadBalancer нельзя использовать, поскольку ваш кластер не настроен на интеграцию с облачным провайдером. Настройка интеграции провайдера облачных вычислений выходит за рамки этого руководства.

##### Получим порт узла, назначенный службе nginx:

```bash
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
```

##### Создаём правило межсетевого экрана, которое позволяет удаленный доступ к порту узла nginx:

```bash
gcloud compute firewall-rules create kubernetes-the-hard-way-allow-nginx-service \
  --allow=tcp:${NODE_PORT} \
  --network kubernetes-the-hard-way
```

> output

```markdown
Creating firewall...-Created [https://www.googleapis.com/compute/v1/projects/docker-194414/global/firewalls/kubernetes-the-hard-way-allow-nginx-service].                                                   
Creating firewall...done.                                                                                                                                                                                   
NAME                                         NETWORK                  DIRECTION  PRIORITY  ALLOW      DENY
kubernetes-the-hard-way-allow-nginx-service  kubernetes-the-hard-way  INGRESS    1000      tcp:31959
```
##### Извлеките внешний IP-адрес воркера:

```bash
EXTERNAL_IP=$(gcloud compute instances describe worker-0 \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
```
##### Сделаем запрос HTTP с использованием внешнего IP-адреса и порта узла nginx:

```bash
curl -I http://${EXTERNAL_IP}:${NODE_PORT}
```

> output

```markdown
HTTP/1.1 200 OK
Server: nginx/1.13.10
Date: Sun, 01 Apr 2018 09:17:25 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 20 Mar 2018 10:03:54 GMT
Connection: keep-alive
ETag: "5ab0dc8a-264"
Accept-Ranges: bytes
```



### Задание 

• Создайте собственные файлы с Deployment манифестами приложений и сохраните в папке kubernetes

    • post-deployment.yml
    
```yamlex
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: post-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: post
  template:
    metadata:
      name: post
      labels:
        app: post
    spec:
      containers:
      - image: asomir/post
        name: post
```

    • ui-deployment.yml
    
```yamlex
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: ui-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ui
  template:
    metadata:
      name: ui
      labels:
        app: ui
    spec:
      containers:
      - image: asomir/ui
        name: ui
```

    • comment-deployment.yml
    
```yamlex
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: comment-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: comment
  template:
    metadata:
      name: comment
      labels:
        app: comment
    spec:
      containers:
      - image: asomir/comment
        name: comment
```
    • mongo-deployment.yml
    
```yamlex
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: mongo-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      name: mongo
      labels:
        app: mongo
    spec:
      containers:
      - image: mongo:3.2
        name: mongo
```    
  

##### Проверьте, что kubectl apply -f <filename> проходит по созданным до этого deployment-ам (ui, post, mongo, comment) и поды запускаются

```bash
kubectl get pods
```
> output

```markdown
NAME                                  READY     STATUS    RESTARTS   AGE
busybox-855686df5d-rz57s              1/1       Running   0          55m
comment-deployment-7ddc57547c-pbb46   1/1       Running   0          2m
comment-deployment-7ddc57547c-r6rzj   1/1       Running   0          2m
comment-deployment-7ddc57547c-wg599   1/1       Running   0          2m
mongo-deployment-74cccfb8-5hvsf       1/1       Running   0          41s
mongo-deployment-74cccfb8-6jdtq       1/1       Running   0          41s
mongo-deployment-74cccfb8-jl8gr       1/1       Running   0          41s
nginx-8586cf59-2z8qp                  1/1       Running   0          43m
post-deployment-659858f589-7lrfh      1/1       Running   0          2m
post-deployment-659858f589-7pbgp      1/1       Running   0          2m
post-deployment-659858f589-kss7m      1/1       Running   0          2m
ui-deployment-87cbcc7fc-84dc5         1/1       Running   0          2m
ui-deployment-87cbcc7fc-c7lr8         1/1       Running   0          2m
ui-deployment-87cbcc7fc-f4jzt         1/1       Running   0          2m
```

### Удаление всего, что мы понаделали с кровью и потом. 


#### Удаляем инстансы, - воркеры и контроллеры: 

```bash
gcloud -q compute instances delete \
  controller-0 controller-1 controller-2 \
  worker-0 worker-1 worker-2
```
> output

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/instances/controller-0].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/instances/controller-1].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/instances/controller-2].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/instances/worker-0].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/instances/worker-2].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/zones/europe-west1-c/instances/worker-1].
```
##### Удалить внешние сетевые ресурсы балансировки нагрузки:

```bash
gcloud -q compute forwarding-rules delete kubernetes-forwarding-rule \
  --region $(gcloud config get-value compute/region)
```

> output

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/forwardingRules/kubernetes-forwarding-rule].
```

```bash
gcloud -q compute target-pools delete kubernetes-target-pool
```
> output 

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/targetPools/kubernetes-target-pool].

```

##### Прикончим статический IP-адрес kubernetes-hard-way:

```bash
gcloud -q compute addresses delete kubernetes-the-hard-way
```
> output 

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/addresses/kubernetes-the-hard-way].
```
##### Сносим правила брандмауэра кубернетов:

```bash
gcloud -q compute firewall-rules delete \
  kubernetes-the-hard-way-allow-nginx-service \
  kubernetes-the-hard-way-allow-internal \
  kubernetes-the-hard-way-allow-external
```
> output 

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/global/firewalls/kubernetes-the-hard-way-allow-nginx-service].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/global/firewalls/kubernetes-the-hard-way-allow-internal].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/global/firewalls/kubernetes-the-hard-way-allow-external].

```
##### Кончаем маршруты сети Pod:

```bash
gcloud -q compute routes delete \
  kubernetes-route-10-200-0-0-24 \
  kubernetes-route-10-200-1-0-24 \
  kubernetes-route-10-200-2-0-24
```

> output 

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/global/routes/kubernetes-route-10-200-0-0-24].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/global/routes/kubernetes-route-10-200-1-0-24].
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/global/routes/kubernetes-route-10-200-2-0-24].
```
##### Терминатим подсеть kubernetes:

```bash
gcloud -q compute networks subnets delete kubernetes
```
> output 

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/regions/europe-west1/subnetworks/kubernetes].
```


##### Стираем с лица земли сеть VPC kubernetes-the-hard-way

```bash
gcloud -q compute networks delete kubernetes-the-hard-way
```
> output 

```markdown
Deleted [https://www.googleapis.com/compute/v1/projects/docker-194414/global/networks/kubernetes-the-hard-way].
```

Всё. Больше ничего нет. Только  Боль. Уныние. Отчаяние. Всем спасибо. Эти двое суток были потрясающими. 
















# Homework-27

## Docker swarm

### Строим Swarm Cluster


##### Создадим машину master-1

Создадим машину master-1, worker-1, worker-2

```bash
docker-machine create --driver google \
   --google-project  docker-194414  \
   --google-zone europe-west1-b \
   --google-machine-type g1-small \
   --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
   master-1
```
```bash
docker-machine create --driver google \
   --google-project  docker-194414  \
   --google-zone europe-west1-b \
   --google-machine-type g1-small \
   --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
   worker-1
```

```bash
docker-machine create --driver google \
   --google-project  docker-194414  \
   --google-zone europe-west1-b \
   --google-machine-type g1-small \
   --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
   worker-2
```

```bash
eval $(docker-machine env master-1)
```
##### Инициализируем Swarm-mode

```bash
 docker swarm init
```

##### После выполнения swarm init появилось сообщение:
```commandline
Swarm initialized: current node (xu9sufx2b8awxw29fkb55o5o8) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-0tg5nnnphxggtdp85nljlrhk4gjbw9kkheuh0oddldua4sva4b-37xt5a2kuc700a7pa49aui812 10.132.0.2:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

```


##### Кластер создан, в нем теперь есть 1 manager и можно добавить к нему новые ноды.

Выделенная команда позволит добавить только worker-ноды.
Также токен для добавления нод можно сгенерировать токен с помощью
команды:

```bash
docker swarm join-token manager/worker
```




#### Памятка
 
 >если на сервере несколько сетевых интерфейсов или
сервер находится за NAT, то необходимо указывать флаг --
advertise-addr с конкретным адресом публикации.
По-умолчанию это будет <адрес интерфейса>:2377

##### В результате выполнения docker swarm init:

• Текущая нода переключается в Swarm-режим

• Текущая нода назначается в качестве Лидера менеджеров кластера

• Ноде присваивается хостнейм машины

• Менеджер конфигурируется для прослушивания на порту 2377

• Текущая нода получает статус Active, что означает возможность
получать задачи от планировщика

• Запускается внутреннее распределенное хранилище данных Docker
для работы оркестратора

• Генерируются токены для присоединения Worker и Manager нод к кластеру

• Генерируется самоподписный корневый (CA) сертификат для Swarm

• Создается Overlay-сеть Ingress для публикации сервисов наружу


##### На хостах worker-1 и worker-2 выполняем:

```bash
docker swarm join --token SWMTKN-1-0tg5nnnphxggtdp85nljlrhk4gjbw9kkheuh0oddldua4sva4b-37xt5a2kuc700a7pa49aui812 10.132.0.2:2377
```

Подключаемся к master-1 ноде 
eval $(docker-machine env master-1)

Дальше работать будем только с ней. Команды в рамках
Swarm-кластера можно запускать только на Manager-нодах.

##### Проверим состояние кластера.

```bash
docker node ls
```

```commandline
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
xu9sufx2b8awxw29fkb55o5o8 *   master-1            Ready               Active              Leader              18.03.0-ce
wqrt3dr64i3md1i1tej6ek1kd     worker-1            Ready               Active                                  18.03.0-ce
dfiw33hegvqyg9czngss6lp88     worker-2            Ready               Active                                  18.03.0-ce

```

### Stack

• Сервисы и их зависимости объединяем в Stack

• Stack описываем в формате docker-compose (YML)


##### Управляем стеком с помощью команд:

```bash
$ docker stack deploy/rm/services/ls STACK_NAME
```

##### У нас уже есть первичное описание стека для запуска reddit-app в docker-compose.yml. Возьмём с gist: 

https://raw.githubusercontent.com/express42/otus-snippets/master/hw-27/docker-compose.yml


#####  Пока что используем только описание приложения и его зависимостей

$ docker stack deploy --compose-file docker-compose.ym ENV  


##### Docker stack не поддерживает переменные окружения и .env файлы: 

```bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV
```

##### Посмотреть состояние стека:

```bash
docker stack services DEV
```
Будете выведена своданая информация по сервисам (не по контейнерам):

```commandline
ID                  NAME                MODE                REPLICAS            IMAGE                   PORTS
0wlndktpczc9        DEV_mongo           replicated          1/1                 mongo:3.2               
isuw3lwbq4p8        DEV_comment         replicated          1/1                 asomir/comment:latest   
rzdpgqnglgso        DEV_ui              replicated          1/1                 asomir/ui:latest        *:9292->9292/tcp
v1cku1utk7iq        DEV_post            replicated          1/1                 asomir/post:latest      

```
### Размещаем сервисы


Ограничения размещения определяются с помощью
логических действий со значениями label-ов (медатанных) нод
и docker-engine’ов

Обращение к встроенным label’ам нод - node.*
Обращение к заданным вручную label’ам нод - node.labels*
Обращение к label’ам engine - engine.labels.*

Примеры:
- node.labels.reliability == high
- node.role != manager
- engine.labels.provider == google

### Labels

##### Добавим label к ноде

```bash
docker node update --label-add reliability=high master-1
```

Swarm не умеет фильтровать вывод по label-ам нод пока что

```bash
docker node ls --filter "label=reliability"
```

##### Посмотреть label’ы всех нод можно так:

```bash
docker node ls -q | xargs docker node inspect  -f '{{ .ID }} [{{ .Description.Hostname }}]: {{ .Spec.Labels }}'
```
##### Предположим, что нода master-1 надежнее и дороже, чем worker-ноды, поэтому поместим туда нашу базу. Определим с помощью placement constraints ограничения размещения

````yamlex
services:
  mongo:
    image: mongo:${MONGO_VERSION}
    deploy:
      placement:
        constraints:
          - node.labels.reliability == high
    volumes:
      - mongo_data:/data/db
    networks:
      back_net:
        aliases:
          - post_db
          - comment_db
````

##### Основную нагрузку пользователей reddit-app будем принимать на worker-ноды, чтобы не перегружать master с помощью label node.role

````yamlex
version: '3.5'
services:

  mongo:
    image: mongo:3.2
    deploy:
      placement:
        constraints:
          - node.labels.reliability == high
    volumes:
      - mongo_data:/data/db
    networks:
      back_net:
        aliases:
          - post_db
          - comment_db

  post:
    image: ${USER_NAME}/post:latest
    deploy:
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  comment:
    image: ${USER_NAME}/comment:latest
    deploy:
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  ui:
    image: ${USER_NAME}/ui:latest
    deploy:
      placement:
        constraints:
          - node.role == worker
    ports:
      - "${UI_PORT}:9292/tcp"
    networks:
      - front_net

volumes:
  mongo_data: {}

networks:
  back_net: {}
  front_net: {}
````
##### Deploy

````bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV
````

##### Посмотрим статусы текущих задач (конетейнеров) в стеке

```bash
docker stack ps DEV
```
```commandline
ID                  NAME                IMAGE                   NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
836bqjmxzknt        DEV_post.1          asomir/post:latest      worker-1            Running             Running 17 minutes ago                       
vd95hw5ezi1x        DEV_mongo.1         mongo:3.2               master-1            Running             Running 17 minutes ago                       
waqt3zjg2sli        DEV_comment.1       asomir/comment:latest   worker-2            Running             Running 17 minutes ago                       
j7sipv4mhhrv        DEV_ui.1            asomir/ui:latest        worker-1            Running             Running 17 minutes ago                       

```

### Масштабируем сервисы

Для горизонтального масшатбирования и большей отказоустойчивости запустим микросервисы в нескольких экземплярах.
Существует 2 варианта запуска:

• replicated mode - запустить определенное число задач (default)

• global mode - запустить задачу на каждой ноде

!!! Нельзя заменить replicated mode на global mode ( и обратно) без удаления сервиса

Будем использовать Replicated mode

Запустим приложения ui, post и comment в 2-х экземплярах

```yamlex
version: '3.5'
services:
...

  post:
    image: ${USER_NAME}/post:latest
    deploy:
      mode: replicated
      replicas: 2
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  comment:
    image: ${USER_NAME}/comment:latest
    deploy:
      mode: replicated
      replicas: 2
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  ui:
    image: ${USER_NAME}/ui:latest
    deploy:
      mode: replicated
      replicas: 2
      placement:
        constraints:
          - node.role == worker
    ports:
      - "${UI_PORT}:9292/tcp"
    networks:
      - front_net
...
```

##### Deploy

```bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV

```

##### Проверим что получилось

```bash
docker stack services DEV
```

```commandline
ID                  NAME                MODE                REPLICAS            IMAGE                   PORTS
0wlndktpczc9        DEV_mongo           replicated          1/1                 mongo:3.2               
isuw3lwbq4p8        DEV_comment         replicated          2/2                 asomir/comment:latest   
rzdpgqnglgso        DEV_ui              replicated          2/2                 asomir/ui:latest        *:9292->9292/tcp
v1cku1utk7iq        DEV_post            replicated          2/2                 asomir/post:latest      

```




Сервисы  распределились равномерно по кластеру (стратегия spread) (проверяем)

```bash
docker stack ps DEV
```
```commandline
836bqjmxzknt        DEV_post.1          asomir/post:latest      worker-1            Running             Running 26 minutes ago                           
vd95hw5ezi1x        DEV_mongo.1         mongo:3.2               master-1            Running             Running 26 minutes ago                           
waqt3zjg2sli        DEV_comment.1       asomir/comment:latest   worker-2            Running             Running 26 minutes ago                           
j7sipv4mhhrv        DEV_ui.1            asomir/ui:latest        worker-1            Running             Running 27 minutes ago                           
yle6wlbgt7ls        DEV_comment.2       asomir/comment:latest   worker-1            Running             Running about a minute ago                       
o0je63lkz2c3        DEV_ui.2            asomir/ui:latest        worker-2            Running             Running about a minute ago                       
06yr6yn151vo        DEV_post.2          asomir/post:latest      worker-2            Running             Running about a minute ago           
```

##### Можно управлять кол-вом запускаемых сервисов “налету”: 

```bash
$ docker service scale DEV_ui=3
```

ИЛИ

```bash
$ docker service update --replicas 3 DEV_ui
```

##### Выключить все задачи сервиса:

```bash
$ docker service update --replicas 0 DEV_ui
```

### Global Mode

Для задач мониторинга кластера нам понадобится запускать node_exporter (только в 1-м экземпляре)

##### Используем global mode

```yamlex
node-exporter:
  image: prom/node-exporter:v0.15.0
  deploy:
    mode: global
```

##### Deploy

```bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose-monitoring.yml config 2>/dev/null) DEV
```
##### Проверяем, что получилось: 

```commandline
ID                  NAME                                          IMAGE                        NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
0db4c3irczni        DEV_node-exporter.dfiw33hegvqyg9czngss6lp88   prom/node-exporter:v0.15.2   worker-2            Running             Running about a minute ago                       
tsokokwzs79k        DEV_node-exporter.wqrt3dr64i3md1i1tej6ek1kd   prom/node-exporter:v0.15.2   worker-1            Running             Running about a minute ago                       
lld3cn9wt71c        DEV_node-exporter.xu9sufx2b8awxw29fkb55o5o8   prom/node-exporter:v0.15.2   master-1            Running             Running about a minute ago                       
vajezlu3lwvr        DEV_grafana.1                                 grafana/grafana:5.0.0        master-1            Running             Running about a minute ago                       
qdw3f5p02sx2        DEV_cadvisor.1                                google/cadvisor:v0.29.0      worker-2            Running             Running about a minute ago                       
c12ifi1ogvjp        DEV_alertmanager.1                            asomir/alertmanager:latest   master-1            Running             Running about a minute ago                       
013atvpy3wpo        DEV_prometheus.1                              asomir/prometheus:latest     master-1            Running             Running about a minute ago                       
836bqjmxzknt        DEV_post.1                                    asomir/post:latest           worker-1            Running             Running 39 minutes ago                           
vd95hw5ezi1x        DEV_mongo.1                                   mongo:3.2                    master-1            Running             Running 39 minutes ago                           
waqt3zjg2sli        DEV_comment.1                                 asomir/comment:latest        worker-2            Running             Running 39 minutes ago                           
j7sipv4mhhrv        DEV_ui.1                                      asomir/ui:latest             worker-1            Running             Running 39 minutes ago                           
yle6wlbgt7ls        DEV_comment.2                                 asomir/comment:latest        worker-1            Running             Running 14 minutes ago                           
o0je63lkz2c3        DEV_ui.2                                      asomir/ui:latest             worker-2            Running             Running 14 minutes ago                           
06yr6yn151vo        DEV_post.2                                    asomir/post:latest           worker-2            Running             Running 14 minutes ago                           
r5k2puu687cb        DEV_ui.3                                      asomir/ui:latest             worker-1            Running             Running 7 minutes ago                            

```

### Самостоятельное задание 

#### Добавляем в кластер ещё один воркер 

##### Заводим машину 

```bash
docker-machine create --driver google \
   --google-project  docker-194414  \
   --google-zone europe-west1-b \
   --google-machine-type g1-small \
   --google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
   worker-3
```
##### Подключаемся к ней

```bash
eval $(docker-machine env worker-3)
```

##### Джойним к кластеру 

```bash
docker swarm join --token SWMTKN-1-0tg5nnnphxggtdp85nljlrhk4gjbw9kkheuh0oddldua4sva4b-37xt5a2kuc700a7pa49aui812 10.132.0.2:2377
```
```commandline
This node joined a swarm as a worker.
```

##### Проверяем, как распределились сервисы

````bash
docker stack ps DEV

````
```commandline
ID                  NAME                                          IMAGE                        NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
tdltc39nj8zi        DEV_node-exporter.sxvb300vi5n1qw3oj5hhxdoeu   prom/node-exporter:v0.15.2   worker-3            Running             Running about a minute ago                       
0db4c3irczni        DEV_node-exporter.dfiw33hegvqyg9czngss6lp88   prom/node-exporter:v0.15.2   worker-2            Running             Running 7 minutes ago                            
tsokokwzs79k        DEV_node-exporter.wqrt3dr64i3md1i1tej6ek1kd   prom/node-exporter:v0.15.2   worker-1            Running             Running 7 minutes ago                            
lld3cn9wt71c        DEV_node-exporter.xu9sufx2b8awxw29fkb55o5o8   prom/node-exporter:v0.15.2   master-1            Running             Running 7 minutes ago                            
vajezlu3lwvr        DEV_grafana.1                                 grafana/grafana:5.0.0        master-1            Running             Running 7 minutes ago                            
qdw3f5p02sx2        DEV_cadvisor.1                                google/cadvisor:v0.29.0      worker-2            Running             Running 7 minutes ago                            
c12ifi1ogvjp        DEV_alertmanager.1                            asomir/alertmanager:latest   master-1            Running             Running 7 minutes ago                            
013atvpy3wpo        DEV_prometheus.1                              asomir/prometheus:latest     master-1            Running             Running 7 minutes ago                            
836bqjmxzknt        DEV_post.1                                    asomir/post:latest           worker-1            Running             Running 45 minutes ago                           
vd95hw5ezi1x        DEV_mongo.1                                   mongo:3.2                    master-1            Running             Running 45 minutes ago                           
waqt3zjg2sli        DEV_comment.1                                 asomir/comment:latest        worker-2            Running             Running 45 minutes ago                           
j7sipv4mhhrv        DEV_ui.1                                      asomir/ui:latest             worker-1            Running             Running 45 minutes ago                           
yle6wlbgt7ls        DEV_comment.2                                 asomir/comment:latest        worker-1            Running             Running 19 minutes ago                           
o0je63lkz2c3        DEV_ui.2                                      asomir/ui:latest             worker-2            Running             Running 20 minutes ago                           
06yr6yn151vo        DEV_post.2                                    asomir/post:latest           worker-2            Running             Running 20 minutes ago                           
r5k2puu687cb        DEV_ui.3                                      asomir/ui:latest             worker-1            Running             Running 13 minutes ago                           

```

> Видим, что на worker-3 появился только DEV_node-exporter.sxvb300vi5n1qw3oj5hhxdoeu

##### Увеличиваем количество сервисов до 3

```yamlex
  post:
    image: ${USER_NAME}/post:latest
    deploy:
      mode: replicated
      replicas: 3
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  comment:
    image: ${USER_NAME}/comment:latest
    deploy:
      mode: replicated
      replicas: 3
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  ui:
    image: ${USER_NAME}/ui:latest
    deploy:
      mode: replicated
      replicas: 3
      placement:
        constraints:
          - node.role == worker
    ports:
      - "${UI_PORT}:9292/tcp"
    networks:
      - front_net
```

##### Разворачиваем сервисы

```bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV
```

##### Проверяем, что получилось: 

```bash
docker stack ps DEV
```
```commandline
ID                  NAME                                          IMAGE                        NODE                DESIRED STATE       CURRENT STATE               ERROR               PORTS
tdltc39nj8zi        DEV_node-exporter.sxvb300vi5n1qw3oj5hhxdoeu   prom/node-exporter:v0.15.2   worker-3            Running             Running 7 minutes ago                           
0db4c3irczni        DEV_node-exporter.dfiw33hegvqyg9czngss6lp88   prom/node-exporter:v0.15.2   worker-2            Running             Running 14 minutes ago                          
tsokokwzs79k        DEV_node-exporter.wqrt3dr64i3md1i1tej6ek1kd   prom/node-exporter:v0.15.2   worker-1            Running             Running 14 minutes ago                          
lld3cn9wt71c        DEV_node-exporter.xu9sufx2b8awxw29fkb55o5o8   prom/node-exporter:v0.15.2   master-1            Running             Running 14 minutes ago                          
vajezlu3lwvr        DEV_grafana.1                                 grafana/grafana:5.0.0        master-1            Running             Running 13 minutes ago                          
qdw3f5p02sx2        DEV_cadvisor.1                                google/cadvisor:v0.29.0      worker-2            Running             Running 14 minutes ago                          
c12ifi1ogvjp        DEV_alertmanager.1                            asomir/alertmanager:latest   master-1            Running             Running 13 minutes ago                          
013atvpy3wpo        DEV_prometheus.1                              asomir/prometheus:latest     master-1            Running             Running 13 minutes ago                          
836bqjmxzknt        DEV_post.1                                    asomir/post:latest           worker-1            Running             Running about an hour ago                       
vd95hw5ezi1x        DEV_mongo.1                                   mongo:3.2                    master-1            Running             Running about an hour ago                       
waqt3zjg2sli        DEV_comment.1                                 asomir/comment:latest        worker-2            Running             Running about an hour ago                       
j7sipv4mhhrv        DEV_ui.1                                      asomir/ui:latest             worker-1            Running             Running about an hour ago                       
yle6wlbgt7ls        DEV_comment.2                                 asomir/comment:latest        worker-1            Running             Running 26 minutes ago                          
o0je63lkz2c3        DEV_ui.2                                      asomir/ui:latest             worker-2            Running             Running 26 minutes ago                          
06yr6yn151vo        DEV_post.2                                    asomir/post:latest           worker-2            Running             Running 26 minutes ago                          
mtzgtmyr33ex        DEV_post.3                                    asomir/post:latest           worker-3            Running             Preparing 28 seconds ago                        
uoksf6n7k4w0        DEV_comment.3                                 asomir/comment:latest        worker-3            Running             Preparing 39 seconds ago                        
r5k2puu687cb        DEV_ui.3                                      asomir/ui:latest             worker-1            Running             Running 20 minutes ago                          

```

Задание со звездой: 

Видим, что сервисы распределились равномерно по всем нодам. node-exporter автоматически запустился на новой ноде, как только мы её добавили.
Делаем вывод, что её заставил так вести mode: global


### Как мы общаемся с приложением?

##### У ui-компоненты приложения уже должен быть выставлен expose-порт, поэтому дополнять там ничего не нужно.


```yamlex
ports:
    - "${UI_PORT}:9292/tcp"
```

Однако отметим, что внутренний механизм Routing mesh
обеспечивает балансировку запросов пользователей
между контейнерами UI-сервиса.
1) В независимости от того, на какую ноду прийдет запрос,
мы попадем на приложение (которое было опубликовано)
2) Каждое новое TCP/UDP-соединение будет отправлено на
следующий endpoint (round-robin балансировка)

##### 1. Посмотрим, где запущен UI-сервис:

```bash
$ docker service ps DEV_ui
```
```commandline
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE          ERROR               PORTS
j7sipv4mhhrv        DEV_ui.1            asomir/ui:latest    worker-1            Running             Running 10 hours ago                       
o0je63lkz2c3        DEV_ui.2            asomir/ui:latest    worker-2            Running             Running 10 hours ago                       
r5k2puu687cb        DEV_ui.3            asomir/ui:latest    worker-1            Running             Running 10 hours ago                       

```


##### 2. Получим список адресов:
 ```bash
docker-machine ip $(docker-machine ls -q)
```
##### 3. Зайдём в браузере на каждую из машин (с интервалом в 10-15с). Обратим внимание на id-контейнера

```markdown
worker-1
http://35.205.186.249:9292/
Microservices Reddit in 5e545064a8f6 container

master-1
http://35.205.239.130:9292/
Microservices Reddit in 2ef6f9aac0ee container

worker-2  
http://35.189.241.95:9292/
Microservices Reddit in 5e545064a8f6 container

worker-3  
http://35.205.173.12:9292/
Microservices Reddit in 84ab726a4fc9 container

```

##### 4. ID не сходятся, потому что рамках кластера минимальная единица - это задача (task). Контейнер - лишь конкретный экземпляр задачи.

##### ID контейнера можно увидеть, если выполнить

```bash
 docker inspect $(docker stack ps DEV -q --filter "Name=DEV_ui.1") --format "{{.Status.ContainerStatus.ContainerID}}"
```

### update_config

##### Чтобы обеспечить минимальное время простоя приложения во время обновлений (zero-downtime), сконфигурируем параметры деплоя параметром update_config

```yamlex
service:
    image: svc
    deploy:
      update_config:
        parallelism: 2            # cколько контейнеров (группу) обновить одновременно?
        delay: 5s                 # задержка между обновлениями групп контейнеров
        failure_action: rollback  # что делать, если при обновлении возникла ошибка
        monitor: 5s               # сколько следить за обновлением, пока не признать его удачным или ошибочным
        max_failure_ratio: 2      # сколько раз обновление может пройти с ошибкой перед тем, как перейти к failure_action
        order: start-first        # порядок обновлений (сначала убиваем старые и запускаем новые или наоборот) (только в compose 3.4)
```

### Памятка 

1) parallelism - cколько контейнеров (группу) обновить
одновременно?
2) delay - задержка между обновлениями групп контейнеров
3) order - порядок обновлений (сначала убиваем старые и
запускаем новые или наоборот) (только в compose 3.4)
Обработка ошибочных ситуаций
4) failure_action - что делать, если при обновлении возникла ошибка
5) monitor - сколько следить за обновлением, пока не признать его
удачным или ошибочным
6) max_failure_ratio - сколько раз обновление может пройти с
ошибкой перед тем, как перейти к failure_action


##### Определим, что приложение UI должно обновляться группами по 1 контейнеру с разрывом в 5 секунд.
В случае возникновения проблем деплой останавливается (Старые и новые версии работают вместе)

```yamlex
services:
  ui:
    image: ${USER_NAME}/ui:${UI_VERSION}
    deploy:
      replicas: 3
      update_config:
        delay: 5s
        parallelism: 1
        failure_action: rollback
      mode: replicated
      placement:
        constraints:
          - node.role == worker
    ports:
      - "${UI_PORT}:9292/tcp"
    networks:
      - front_net
```

### failure_action

Что делать, если обновление прошло с ошибкой?
 - rollback - откатить все задачи на предыдущую версию
 - pause (default) - приостановить обновление
 - continue - продолжить обновление


##### Deploy 

```bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV
```
##### Отслеживаем изменения

```bash
 docker service ps DEV_ui
```

### Задание

###### Определить update_config для сервисов post и comment так, чтобы они обновлялись группами по 2 сервиса с разрывом в 10 секунд, а в случае неудач осуществлялся rollback.
Отразить изменения в docker-compose.yml


```yamlex
  post:
    image: ${USER_NAME}/post:latest
    deploy:
      mode: replicated
      replicas: 3
      update_config:
        delay: 10s
        parallelism: 2
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  comment:
    image: ${USER_NAME}/comment:latest
    deploy:
      mode: replicated
      replicas: 3
      update_config:
        delay: 10s
        parallelism: 2
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net


  ui:
    image: ${USER_NAME}/ui:${UI_VERSION}
    deploy:
      replicas: 3
      update_config:
        delay: 5s
        parallelism: 1
        failure_action: rollback
      mode: replicated
      placement:
        constraints:
          - node.role == worker
    ports:
      - "${UI_PORT}:9292/tcp"
    networks:
      - front_net
```

### Ограничиваем ресурсы


С помощью resources limits описываем максимум потребляемых
приложениями CPU и памяти. Это обеспечит нам:
1) Представление о том, сколько ресурсов нужно приложению
2) Контроль Docker за тем, чтобы никто не превысил заданного порога (с помощью
cgroups)
3) Защиту сторонних приложений от неконтролируемого расхода ресурса контейнером

### Задание
##### Задать ограничения ресурсов для сервисов post и comment, ограничив каждое в 300 мегабайт памяти и в 30% процессорного времени. Изменения отразить в docker-compose.yml

```yamlex
  post:
    image: ${USER_NAME}/post:latest
    deploy:
      resources:
        limits:
          cpus: '0.30'
          memory: 300M
      mode: replicated
      replicas: 3
      update_config:
        delay: 10s
        parallelism: 2
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  comment:
    image: ${USER_NAME}/comment:latest
    deploy:
      resources:
        limits:
          cpus: '0.30'
          memory: 300M
      mode: replicated
      replicas: 3
      update_config:
        delay: 10s
        parallelism: 2
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net


  ui:
    image: ${USER_NAME}/ui:${UI_VERSION}
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 150M
      replicas: 3
      update_config:
        delay: 5s
        parallelism: 1
        failure_action: rollback
      mode: replicated
      placement:
        constraints:
          - node.role == worker
    ports:
      - "${UI_PORT}:9292/tcp"
    networks:
      - front_net
```
### Restart policy

Если контейнер в рамках задачи завершит свою работу, то планировщик Swarm
автоматически запустит новый (даже если он вручную остановлен).

Мы можем поменять это поведение (для целей диагностики, например) так, чтобы
контейнер перезапускался только при падении контейнера (on-failure).

По-умолчанию контейнер будет бесконечно перезапускаться. Это может оказать
сильную нагрузку на машину в целом. 

##### Ограничим число попыток перезапуска 3-мя с интервалом в 3 секунды.

```yamlex
  ui:
    image: ${USER_NAME}/ui:${UI_VERSION}
    deploy:
      restart_policy:
        condition: on-failure
        max_attempts: 3
        delay: 3s
      resources:
        limits:
          cpus: '0.50'
          memory: 150M
      replicas: 3
      update_config:
        delay: 5s
        parallelism: 1
        failure_action: rollback
      mode: replicated
      placement:
        constraints:
          - node.role == worker

```
### Задание

##### Задайте политику перезапуска для comment и post сервисов так, чтобы Swarm пытался перезапустить их при падении с ошибкой 10-15 раз с интервалом в 1 секунду.
##### Изменения отразить в docker-compose.yml

```yamlex
  post:
    image: ${USER_NAME}/post:latest
    deploy:
      restart_policy:
        condition: on-failure
        max_attempts: 12
        delay: 1s
      resources:
        limits:
          cpus: '0.30'
          memory: 300M
      mode: replicated
      replicas: 3
      update_config:
        delay: 10s
        parallelism: 2
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net

  comment:
    image: ${USER_NAME}/comment:latest
    deploy:
      restart_policy:
        condition: on-failure
        max_attempts: 13
        delay: 1s
      resources:
        limits:
          cpus: '0.30'
          memory: 300M
      mode: replicated
      replicas: 3
      update_config:
        delay: 10s
        parallelism: 2
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker
    networks:
      - front_net
      - back_net
```

##### Deploy

```bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose.yml config 2>/dev/null) DEV
```

##### Задание

Помимо сервисов приложения, у вас может быть инфраструктура, описанная в compose-файле (prometheus, node-
exporter, grafana ...)

Нужно выделить ее в отдельный compose-файл. С названием docker-compose-monitoring.yml
В него выносится все что относится к этим сервисам (volumes, services)
Запускать приложение вместе с мониторингом можно следующей командой (команда не работает, выпадает ошибка "Top-level object must be a mapping", хотя частям запускается)

```bash
docker stack deploy --compose-file=<(docker-compose -f docker-compose-monitoring.yml -f docker-compose.yml config 2>/dev/null)  DEV
```







# Homework 25

## Логирование и распределенная трассировка

### Plan

• Сбор неструктурированных логов
• Визуализация логов
• Сбор структурированных логов
• Распределенная трасировка

## Подготовимся

##### Создали Docker хост в GCE и настроили локальное окружение на работу с ним:

```bash
export GOOGLE_PROJECT=docker-194414
```

```bash
 docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-open-port 5601/tcp \
    --google-open-port 9292/tcp \
    --google-open-port 9411/tcp \
    logging

```

##### configure local env

> eval $(docker-machine env logging)

##### узнаем IP адрес

> docker-machine ip logging

35.193.44.87

• Экспортируем имя пользователя 

```bash
export USER_NAME=asomir
```

• Обновили код в директории /src вашего репозитория из кода по ссылке.

ЗАБЫЛИ ДОКЕРФАЙЛЫ, ВЕРНУЛИ НА МЕСТО!

• Выполнили сборку образов при помощи скриптов docker_build.sh в директории каждого сервиса:

```bash
for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done
```

## Elastic Stack

### Памятка: 

Как упоминалось на лекции хранить все логи стоит
централизованно: на одном (нескольких) серверах. В этом ДЗ мы
построим рассмотрим пример построения системы
централизованного логирования на примере Elastic стека (ранее
известного как ELK): который включает в себя 3 осовных компонента:

• ElasticSearch (TSDB и поисковый движок для хранения данных),

• Logstash (для агрегации и трансформации данных),

• Kibana (для визуализации).

Однако для агрегации логов вместо Logstash мы будем использовать
Fluentd, таким образом получая еще одно популярное сочетание этих
инструментов, получившее название EFK.



##### Создадим отдельный compose-файл для нашей системы логирования в папке docker/

> docker/docker-compose-logging.yml

```yamlex
version: '3'
services:

  fluentd:
    build: ./fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"
    networks:
      - back_net
      - front_net
  elasticsearch:
    image: elasticsearch
    expose:
      - 9200
    ports:
      - "9200:9200"
    networks:
      - back_net
      - front_net
  kibana:
    image: kibana
    ports:
      - "5601:5601"
    networks:
      - back_net
      - front_net

networks:
  back_net:
  front_net:
```

##### Откроем порты для 

###### fluentd

```bash
gcloud compute firewall-rules create fluentd-default --allow tcp,udp:24224
```

###### elasticsearch

```bash
gcloud compute firewall-rules create elasticsearch-default --allow tcp:9200
```

###### kibana


```bash
gcloud compute firewall-rules create kibana-default --allow tcp:5601
```


###### Zipkin

```bash
gcloud compute firewall-rules create zipkin-default --allow tcp:9411
```

### Fluentd

Fluentd инструмент, который может использоваться для
отправки, агрегации и преобразования лог-сообщений. Мы
будем использовать Fluentd для агрегации (сбора в одной
месте) и парсинга логов сервисов нашего приложения.
Создадим образ Fluentd с нужной нам конфигурацией.

##### Создали в вашем проекте microservices директорию  docker/fluentd, в ней, создали  Dockerfile со следущим содержимым:

```docker
FROM fluent/fluentd:v0.12
RUN gem install fluent-plugin-elasticsearch --no-rdoc --no-ri --version 1.9.5
RUN gem install fluent-plugin-grok-parser --no-rdoc --no-ri --version 1.0.0
ADD fluent.conf /fluentd/etc
```

```buildoutcfg
<source>
    @type forward # плагин in_forward для приёма логов
    port 24224
    bind 0.0.0.0
</source>
<match *.**>
    @type copy    # copy плагин переправляет все логи в elasticsearch и выводит в output
    <store>
        @type elasticsearch
        host elasticsearch
        port 9200
        logstash_format true
        logstash_prefix fluentd
        logstash_dateformat %Y%m%d
        include_tag_key true
        type_name access_log
        tag_key @log_name
        flush_interval 1s
    </store>
    <store>
        @type stdout
    </store>
</match>
```

### Структурированные логи

Логи должны иметь заданную (единую) структуру и содержать
необходимую для нормальной эксплуатации данного сервиса
информацию о его работе.

Лог-сообщения также должны иметь понятный для выбранной
системы логирования формат, чтобы избежать ненужной траты
ресурсов на преобразование данных в нужный вид.
Структурированные логи мы рассмотрим на примере сервиса
post.


##### Запустим сервисы приложения.

docker/ 

> docker-compose up -d

##### И выполним команду для просмотра логов post сервиса:

docker/ 

>  docker-compose logs -f post

Attaching to reddit_post_1

## Сбор логов Post сервиса

##### Поднимем инфраструктуру централизованной системы логирования и перезапустим сервисы приложения

```bash
docker-compose -f docker-compose-logging.yml up -d
docker-compose down
docker-compose up -d
```
### Kibana

Kibana - инструмент для визуализации и анализа
логов от компании Elastic.
Откроем WEB-интерфейс Kibana для просмотра
собранных в ElasticSearch логов Post-сервиса (kibana
слушает на порту 5601)

http://35.193.44.87:5601

Введем в поле патерна индекса fluentd-* И создадим новый индекс (Create)

Нажмем “Discover”, чтобы посмотреть информацию ополученных лог сообщениях

График покажет в какой момент времени поступало то или иное количество лог сообщений

Нажмем на знак “развернуть” напротив одного из лог сообщений, чтобы посмотреть подробную информацию о нем

Видим лог-сообщение, которые мы недавно наблюдали в терминале. Теперь эти лог-сообщения хранятся централизованно в
ElasticSearch. Также видим доп. информацию о том, откуда поступил данный лог.

Обратим внимание на то, что наименования в левом столбце, называются полями. По полям можно производить поиск для
быстрого нахождения нужной информации

К примеру, посмотрев список доступных полей, мы можем выполнить поиск всех логов, поступивших с контейнера
reddit_post_1





### Фильтры


Заметим, что поле log содержит в себе JSON объект, который содержит много интересной нам информации.

Нам хотелось бы выделить эту информацию в поля, чтобы иметь возможность производить по ним поиск. Например, для того чтобы
найти все логи, связанные с определенным событием (event) или конкретным сервисов (service).
Мы можем достичь этого за счет использования фильтров для выделения нужной информации.


Добавим фильтр для парсинга json логов, приходящих от post сервиса, в конфиг fluentd

```buildoutcfg
<source>
    @type forward
    port 24224
    bind 0.0.0.0
</source>

<filter service.post>
  @type parser
  format json
  key_name log
</filter>

<match *.**>
    @type copy
    <store>
        @type elasticsearch
        host elasticsearch
        port 9200
        logstash_format true
        logstash_prefix fluentd
        logstash_dateformat %Y%m%d
        include_tag_key true
        type_name access_log
        tag_key @log_name
        flush_interval 1s
    </store>
    <store>
        @type stdout
    </store>
</match>
```

##### После этого перезапустили сервис, пересобрав при этом образ fluentd

```bash
docker-compose -f docker-compose-logging.yml up -d --build
```

##### Создадим пару новых постов, чтобы проверить парсинг логов

Вновь обратимся к Kibana. Прежде чем смотреть логи убедимся, что временной интервал выбран верно. Нажмите один раз на дату со временем

### Неструктурированные логи


Неструктурированные логи отличаются отсутствием четкой
структуры данных. Также часто бывает, что формат лог-
сообщений не подстроен под систему централизованного
логирования, что существенно увеличивает затраты
вычислительных и временных ресурсов на обработку данных и
выделение нужной информации.
На примере сервиса ui мы рассмотрим пример логов с
неудобным форматом сообщений.


#### Логирование UI сервиса

По аналогии с post сервисом определим для ui сервиса драйвер для логирования fluentd в compose-файле.


```yaml
version: '3.3'
services:
  post_db:
    image: mongo:${VERSION_MONGO}
    volumes:
      - post_db:/data/db
    networks:
      back_net:
        aliases:
          - post_db
          - comment_db
  ui:
    container_name: ui
    image: ${USERNAME}/ui:latest
    ports:
      - ${APP_PORT}:9292/tcp
    networks:
      - front_net
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.post

  post:
    image: ${USER_NAME}/post:latest
    environment:
      - POST_DATABASE_HOST=post_db
      - POST_DATABASE=posts
    depends_on:
      - post_db
    ports:
      - "5000:5000"
    networks:
      - back_net
      - front_net
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.post

  comment:
    container_name: comment
    image: ${USERNAME}/comment:latest
    networks:
      - back_net
      - front_net


volumes:
  post_db:
  prometheus_data:

networks:
  front_net:
  back_net:
```

##### Перезапустим ui сервис

```bash
docker-compose stop ui
docker-compose rm ui
docker-compose up -d
```

### Парсинг

Когда приложение или сервис не пишет структурированные
логи, приходится использовать старые добрые регулярные
выражения для их парсинга.


##### Следующее регулярное выражение нужно, чтобы успешно выделить интересующую нас информацию из лога UI-сервиса в поля


```buildoutcfg
source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<filter service.post>
  @type parser
  format json
  key_name log
</filter>

<filter service.ui>
  @type parser
  format /\[(?<time>[^\]]*)\]  (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method= (?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
  key_name log
</filter>


<match *.**>
  @type copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>
  <store>
    @type stdout
  </store>
</match>
```
Созданные регулярки могут иметь ошибки, их сложно менять
и невозможно читать.
Для облегчения задачи парсинга вместо стандартных
регулярок можно использовать grok-шаблоны.
По-сути grok’и - это именованные шаблоны регулярных
выражений (очень похоже на функции). Можно использовать
готовый regexp, просто сославшись на него как на функцию.

```buildoutcfg
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<filter service.post>
  @type parser
  format json
  key_name log
</filter>

<filter service.ui>
  @type parser
  key_name log
  format grok
  grok_pattern %{RUBY_LOGGER}
</filter>

<match *.**>
  @type copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>
  <store>
    @type stdout
  </store>
</match>
```

### Zipkin 

##### Firewall rule

> gcloud compute firewall-rules create zipkin-default --allow tcp:9411

##### Добавим в compose-файл для сервисов логирования сервис распределенного трейсинга


```yaml
version: '3'

services:
  zipkin:
    image: openzipkin/zipkin
    ports:
      - "9411:9411"

  fluentd:
    build: ./fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"

  elasticsearch:
    image: elasticsearch
    expose:
      - 9200
    ports:
      - "9200:9200"

  kibana:
    image: kibana
    ports:
      - "8080:5601"
```

##### Пересоздадим наши сервисы

```bash
docker-compose -f docker-compose-logging.yml -f docker-compose.yml down
docker-compose -f docker-compose-logging.yml -f docker-compose.yml up -d
```



# Homework 23

## Мониторинг приложения и инфраструктуры

### Подготовка окружения

##### Создадим Docker хост в GCE и настроим локальное окружение на работу с ним

> export GOOGLE_PROJECT=docker-194414

```bash
docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    vm1
```

> eval $(docker-machine env vm1)
##### Узнаем IP адрес
> docker-machine ip vm1


35.192.64.106



##### Билдим образы сервисов

> cd docker/

> docker-compose up -d

### Мониторинг Docker контейнеров

##### Оставим описание приложений в docker-compose.yml, а мониторинг выделим в отдельный файл docker-compose-monitoring.yml

Для запуска приложений будем как и ранее
использовать 

> docker-compose up -d
 
Для мониторинга -

> docker-compose -f docker-compose-monitoring.yml up -d

### cAdvisor

Мы будем использовать cAdvisor для наблюдения
за состоянием наших Docker контейнеров. cAdvisor
собирает информацию о ресурсах потребляемых
контейнерами и характеристиках их работы.
Примерами метрик являются: процент
использования контейнером CPU и памяти,
выделенные для его запуска, объем сетевого
трафика и др

##### Добавим новый сервис в наш компоуз файл мониторинга, чтобы запускать cAdvisor в контейнере
Поместим его в одну сеть с Прометеем, чтобы он мог собирать с него метрички

docker-compose-monitoring.yml 

```yamlex
cadvisor:
  image: google/cadvisor:v0.29.0
  volumes:
    - '/:/rootfs:ro'
    - '/var/run:/var/run:rw'
    - '/sys:/sys:ro'
    - '/var/lib/docker/:/var/lib/docker:ro'
  ports:
    - '8080:8080'
```

Откроем порт 8080 в GCE 

```bash
gcloud compute firewall-rules create cadvisor-default --allow tcp:8080
```

##### Добавим информацию о новом сервисе в конфигурацию Prometheus, чтобы он начал собирать метрики.

```yamlex
  - job_name: 'cadvisor'
    static_configs:
      - targets:
        - 'cadvisor:8080'
```

##### Пересоберём Прометея с обновлённой конфигурацией

```bash
export USER_NAME=asomir
docker build -t $USER_NAME/prometheus .
cd ../ ../docker
docker-compose down
docker-compose up -d 
docker-compose -f docker-compose-monitoring.yml up -d
```

##### cAdvisor имеет UI, в котором отображается собираемая о контейнерах информация. 

Откроем страницу Web UI по адресу http://104.154.181.55:8080

по пути /metrics все собираемые метрики публикуются для сбора Prometheus

##### Жмахнем на ссылку Docker Containers

###### Кто у нас тут?

```markdown
Subcontainers
comment (/docker/f03c8787bcd9bd98d74f24bc99c81ca959e6b2060e800efcc8454576dc4ffe0b)
post-py (/docker/99c47e0f760bfb1e115ec71ac01a835b1f02f213698f62231d78736ed49ddb66)
ui (/docker/80e8d9da6954faf0eb04a8b665f9a1ae53c6b7834f8cc4b4df307585cf58cd0a)
docker_post_db_1 (/docker/34e1634d3c0251e55c2bd608b58af6ea40151e944d31a80bd0173df45fef3ca6)
docker_node-exporter_1 (/docker/48f5424a7383963b288e9a830f1ca10997ca1bdde526cafc9b67a884935f4d5b)
docker_prometheus_1 (/docker/24c99069cfb8b0ec891bae5a31d947780fa1f1357f91bcf176a60a48d4e8bb66)
docker_cadvisor_1 (/docker/594e93a52e967d2a00a373d3cd776aad9ea504caf912cc4ca2adc808f06c0717)
```


###### Информация о хосте

```markdown
Driver Status
Docker Version 18.02.0-ce
Docker API Version 1.36
Kernel Version 4.13.0-1011-gcp
OS Version Ubuntu 16.04.4 LTS
Host Name vm1
Docker Root Directory /var/lib/docker
Execution Driver
Number of Images 9
Number of Containers 7
Storage
Driver aufs
Root Dir /var/lib/docker/aufs
Backing Filesystem extfs
Dirs 84
Dirperm1 Supported true
```

Проверим, что метрики контейнеров собираются
Prometheus. Введем, слово `container` и посмотрим,
что он предложит дополнить

## Визуализация метрик. Grafana.

##### Используем инструмент Grafana для визуализации данных из Prometheus.

Добавим новый сервис в docker-compose-monitoring.yml

```yamlex
  grafana:
    image: grafana/grafana:5.0.0
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=secret
    depends_on:
      - prometheus
    ports:
      - 3000:3000

volumes:
  grafana_data:

```

##### Запустим новый сервис

> docker-compose -f docker-compose-monitoring.yml up -d grafana

##### Откроем 3000 порт для графаны 

> gcloud compute firewall-rules create grafana-default --allow tcp:3000

##### Откроем страницу Web UI графаны по адресу

http://104.154.181.55:3000

И введём admin secret

##### Добавим источник данных Add Data Source

Сервер назовём Prometheus Server и добавим его по адресу http://104.154.181.55:9090

##### Импортируем Dashboard с сайта https://grafana.com/dashboards : Data Source "Prometheus" - Category "Docker"

###### Docker And System Monitiring сохранили как DockerMonitoring.json

Загрузили источник данных для визуализации Prometheus Server

### Сбор метрик приложения

#### Мониторинг работы приложения

##### Добавим информацию о post сервисе в конфигурацию Prometheus, чтобы он начал собирать метрики и с него.

```yamlex
  - job_name: 'post'
    static_configs:
      - targets:
        - 'post:5000'
```

##### Пересоберем образ Prometheus с обновленной конфигурацией.

```bash
$ export USER_NAME=username
$ docker build -t $USER_NAME/prometheus .
```
##### Пересоздадим нашу Docker инфраструктуру мониторинга:

```bash
$ docker-compose -f docker-compose-monitoring.yml down
$ docker-compose -f docker-compose-monitoring.yml up -d
```

И добавим несколько постов в приложении и несколько коментов, чтобы собрать значения метрик приложения.

##### Для ошибочных запросов сделаем дашборд Rate of UI HTTP Requests with Error

```bash
rate(ui_request_count{http_status=~"^[45].*"}[1m])
```
##### Для UI http requests сделаем запрос 

```bash
rate(ui_request_count{http_status=~"^[23].*"}[1m])
```

### Гистограмма

В Prometheus есть тип метрик histogram. Данный тип
метрик в качестве своего значение отдает ряд
распределения измеряемой величины в заданном
интервале значений.
Мы используем данный тип метрики для измерения
времени обработки HTTP запроса нашим
приложением.

Посмотрим информацию по времени обработки запроса приходящих на
главную страницу приложения

ui_request_latency_seconds_bucket{path="/"}


### Перцентиль

- числовое значение в наборе значений

-  все числа в наборе меньше перцентиля, попадают в границы заданного процента значений от всего числа значений в наборе


Часто для анализа данных мониторинга применяются значения 90, 95 или 99-й перцентиля.
Мы вычислим 95-й перцентиль для выборки времени обработки запросов, чтобы посмотреть
какое значение является максимальной границей для большинства (95%) запросов. Для этого
воспользуемся встроенной функцией histogram_quantile():

##### Добавим новый график на дашборд для вычисления 95 перцентиля времени ответа на запрос


histogram_quantile(0.95, sum(rate(ui_request_latency_seconds_bucket[5m])) by (le))

Сохраним изменения дашборда и эспортируем его в JSON файл, который загрузим на нашу локальную машину

monitoring/grafana/dashboards/UI_Service_Monitoring.json

### Сбор метрик бизнес логики

##### В качестве примера метрик бизнес логики мы в наше приложение мы добавили счетчики количества постов и комментариев.

• post_count

• comment_count

Мы построим график скорости роста значения счетчика за последний час, используя функцию rate().
Это позволит нам получать информацию об активности пользователей приложения.

##### Создали новый дашборд Business_Logic_Monitoring и построили график функции rate(post_count[1h])

##### построили график функции rate(comment_count[1h]) и экспортировали график в monitoring/grafana/dashboards/Business_Logic_Monitoring.json

### Алертинг

#### Правила алертинга

Мы определим несколько правил, в которых зададим условия состояний наблюдаемых систем,
при которых мы должны получать оповещения, т.к. заданные условия могут привести к недоступности
или неправильной работе нашего приложения


##### Alertmanager - дополнительный компонент для системы мониторинга Prometheus, который отвечает за первичную обработку алертов и дальнейшую
отправку оповещений по заданному назначению. Создаём новую директорию monitoring/alertmanager. В этой директории создаём Dockerfile
со следующим содержимым:

```docker
FROM prom/alertmanager:v0.14.0
ADD config.yml /etc/alertmanager/
```

В директории monitoring/alertmanager создали файл config.yml, в
котором определили отправку нотификаций в мой тестовый слак
канал #alexander-akilin.

```yamlex
global:

  slack_api_url: 'https://hooks.slack.com/services/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'
route:
  receiver: 'slack-notifications'
receivers:
  - name: 'slack-notifications'
    slack_configs:
    - channel: '#alexander-akilin'

```

##### Собираем образ alertmanager:

monitoring/alertmanager

```bash
docker build -t $USER_NAME/alertmanager .
```

#####  Добавим новый сервис в компоуз файл

```yamlex
alertmanager:
    image: ${USER_NAME}/alertmanager
    command:
        - '--config.file=/etc/alertmanager/config.yml'
    ports:
        - 9093:9093
```

##### Добавим операцию копирования данного файла в Dockerfile:

monitoring/prometheus/Dockerfile

```yamlex
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
ADD alerts.yml /etc/prometheus/
```

##### Добавим информацию о правилах, в конфиг Prometheus

prometheus.yml

```yamlex
rule_files:
  - "alerts.yml"

alerting:
  alertmanagers:
  - scheme: http
    static_configs:
    - targets:
      - "alertmanager:9093"
```
##### Пересоберем образ Prometheus:

> docker build -t $USER_NAME/prometheus .

##### Пересоздадим сервисы для мониторинга

```bash
docker-compose -f  docker-compose-monitoring.yml down
docker-compose -f  docker-compose-monitoring.yml up -d 

```
##### Откроем порт 9093 для AlertManager

```bash
gcloud compute firewall-rules create alertmanager-default --allow tcp:9093

```

### Завершение работы

##### Запушим собранные образы на DockerHub:


<<<<<<< HEAD

$ docker login
Login Succeeded

```bash
docker push $USER_NAME/ui
docker push $USER_NAME/comment
docker push $USER_NAME/post
docker push $USER_NAME/prometheus
docker push $USER_NAME/alertmanager

```
||||||| merged common ancestors
$ docker login
Login Succeeded

docker push $USER_NAME/ui
docker push $USER_NAME/comment
docker push $USER_NAME/post
docker push $USER_NAME/prometheus
=======
>>>>>>> logging-1


https://hub.docker.com/r/asomir/



# Homework 21

## Введение в мониторинг. Системы мониторинга.

### Подготовка окружения

##### 1. Создадим правило для файерволла Прометеуса и Пумы соответственно:


```bash
$ gcloud compute firewall-rules create prometheus-default --allow tcp:9090

$ gcloud compute firewall-rules create puma-default --allow tcp:9292

```

##### 2. Создадим Docker хост в GCE и настроим локальное окружение на работу с ним

> export GOOGLE_PROJECT=docker-194414

##### 3. Создаём докер хост, с которым мы и будем работать

```bash
# create docker host
docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    vm1
```
##### 4. Подключаемся к докер машине
```bash
# configure local env
eval $(docker-machine env vm1)

```

### Запуск Prometheus

##### 5. Запускаем Прометея внутри докер контейнера. Коварно воспользуемся готовым образом:

```bash
$ docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus:v2.1.0
```
проверяем ШуЗы Прометея

```bash
docker-machine ip vm1
```

и идём по полученному ШуЗу http://35.225.212.35:9090/graph

### Targets

##### Памятка:

Targets (цели) - представляют собой системы или процессы, за
которыми следит Prometheus. Помним, что Prometheus является
pull системой, поэтому он постоянно делает HTTP запросы на
имеющиеся у него адреса (endpoints). Посмотрим текущий список
целей

В Targets сейчас мы видим только сам Prometheus. У каждой
цели есть свой список адресов (endpoints), по которым
следует обращаться для получения информации.

В веб интерфейсе мы можем видеть состояние каждого
endpoint-а (up); лейбл (instance="someURL"), который
Prometheus автоматически добавляет к каждой метрике,
получаемой с данного endpoint-а; а также время,
прошедшее с момента последней операции сбора
информации с endpoint-а.

Также здесь отображаются ошибки при их наличии и можно
отфильтровать только неживые таргеты.

Мы можем открыть страницу в веб браузере по данному HTTP
пути (host:port/metrics), чтобы посмотреть, как выглядит та
информация, которую собирает Prometheus.

##### Остановим Прометея

```bash
docker stop prometheus
```

### Создание Docker образа

##### 6. Создаём докер файл monitoring/prometheus/Dockerfile, который копирует файл конфигурации с нашей машины внутрь контейнера:

```docker
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
```

##### 7. В директории monitoring/prometheus создали файл prometheus.yml

```yamlex
global:
  scrape_interval: '5s' # частота сбора метрик 

scrape_configs: # Эндпойнты - группы метрик, собирающих одинаковые данные
  - job_name: 'prometheus'
    static_configs:
      - targets:
        - 'localhost:9090' # адрес, откуда чо собираем

  - job_name: 'ui'
    static_configs:
      - targets:
        - 'ui:9292'

  - job_name: 'comment'
    static_configs:
      - targets:
        - 'comment:9292'
```

##### 8. В директории prometheus собираем Docker образ:

```bash
$ export USER_NAME=asomir
$ docker build -t $USER_NAME/prometheus .
```

### Образы микросервисов

##### 9. Сборку образов производим при помощи скриптов docker_build.sh, которые есть в директории каждого сервиса. С его помощью мы добавим информацию из Git в наш healthcheck.

Запустиим сразу все из корня репы и пойдём пить кофе

```bash
for i in ui post-py comment; do cd src/$i; bash
docker_build.sh; cd -; done
```

##### 10. Определиv в вашем docker/docker-compose.yml файле новый сервис.

```yamlex
version: '3.3'
services:
  post_db:
    image: mongo:${VERSION_MONGO}
    volumes:
      - post_db:/data/db
    networks:
      back_net:
        aliases:
          - post_db
          - comment_db
  ui:
    container_name: ui
    image: ${USERNAME}/ui:latest
    ports:
      - ${APP_PORT}:9292/tcp
    networks:
      - front_net
  post:
    container_name: post-py
    image: ${USERNAME}/post:latest
    networks:
      - front_net
      - back_net
  comment:
    container_name: comment
    image: ${USERNAME}/comment:latest
    networks:
      - back_net
      - front_net

  prometheus:
    image: ${USER_NAME}/prometheus
    ports:
      - '9090:9090'
    volumes:
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d'
    networks:
      - back_net
      - front_net



volumes:
  post_db:
  prometheus_data:

networks:
  front_net:
  back_net:
```
Запускаем docker-compose up -d и проверяем работоспособность 

http://35.225.212.35:9090/graph
http://35.225.212.35:9292/




### Мониторинг состояния микросервисов

Проверяем состояние наших эндпойнтов: comment, ui, prometheus

http://35.225.212.35:9090/targets

### Healthchecks

#### Памятка 


Healthcheck-и представляют собой проверки того, что
наш сервис здоров и работает в ожидаемом режиме. В
нашем случае healthcheck выполняется внутри кода
микросервиса и выполняет проверку того, что все
сервисы, от которых зависит его работа, ему доступны.
Если требуемые для его работы сервисы здоровы, то
healthcheck проверка возвращает status = 1, что
соответсвует тому, что сам сервис здоров.
Если один из нужных ему сервисов нездоров или
недоступен, то проверка вернет status = 0.

#### Состояние сервиса UI

Выполнили поиск в веб-интерфейсе прометея ui_health, однако он ничего не нашёл. Зашёл на сайт реддит и сделал пост, - после этого Прометей нашёл метрику

ui_health{branch="monitoring-1",commit_hash="d3d08a6",instance="ui:9292",job="ui",version="0.0.1"}

Где показано название ветки в гите, коммите и лейблах

Перешли в графическое отображение, увидели единицу, и она прекрасна. Остановили сервис post.

> docker-compose stop post

график упал в ноль. И это ужасно. Поплачем друзья, ведь сервис нездоров.

Зашёл посмотреть на ui_health_comment_availability и вижу прекрасную единицу.

Зашёл глянуть на ui_health_post_availability и обожечки! Что я вижу! Полный ноль! Сервис мёртв! Что же делать?!

Поднимем же сервис пост, вставай, дружочек:

> docker-compose start post

ui_health_post_availability{branch="monitoring-1",commit_hash="d3d08a6",instance="ui:9292",job="ui",version="0.0.1"}

Жив и здоров, мы пришили ему ножки! 

## Exporters

#### Памятка 

• Программа, которая делает метрики доступными
для сбора Prometheus 

• Дает возможность конвертировать метрики в
нужный для Prometheus формат 

• Используется когда нельзя поменять код
приложения 

• Примеры: PostgreSQL, RabbitMQ, Nginx, Node
exporter, cAdvisor 

### Node exporter

##### Определим еще один сервис в docker/docker-compose.yml файле.

```yamlex
services:

  node-exporter:
    image: prom/node-exporter:v0.15.2
    user: root
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
```

##### Добавим слежение за новым сервисом в Прометей

```yamlex
  - job_name: 'node'
    static_configs:
      - targets:
        - 'node-exporter:9100'
```
##### Пересоздадим докер для Прометея

monitoring/prometheus 

```bash
$ docker build -t $USER_NAME/prometheus .
```

##### Пересоздадим наши сервисы

```bash
$ docker-compose down
$ docker-compose up -d
```
В списке эндпойнтов появился ещё один сервис node

##### Получим информацию об использовании CPU 

Зайдем на хост: 

> docker-machine ssh vm1 

Добавим нагрузки: 

yes > /dev/null


Посмотрим на весёлые графики

##### Запушили собранные образы на DockerHub:
$ docker login
Login Succeeded

docker push $USER_NAME/ui
docker push $USER_NAME/comment
docker push $USER_NAME/post
docker push $USER_NAME/prometheus




Удалили виртуалку:
$ docker-machine rm vm1

## Ссылка на мой репозиторий: 

https://hub.docker.com/r/asomir/



# Homework 20

## Устройство Gitlab CI. Непрерывная поставка

###### Создали новый проект example2, добавили remote в asomir_microservices

> git checkout -b docker-7
> git remote add gitlab2 http://35.195.25.42/homework/example2.git
> git push gitlab2 docker-7

### Pipeline

##### Включили runner, поправили .gitlab-ci.yml

```yamlex
image: ruby:2.4.2

stages:       # в каких окружениях что происходить будет
  - build
  - test
  - review
  - stage
  - production

variables:
  DATABASE_URL: 'mongodb://mongo/user_posts'

before_script:    # что бы запустить в самом начале
  - cd reddit
  - bundle install

build_job:        # билдим
  stage: build
  script:
    - echo 'Building'

test_unit_job:    # юнит тестирование
  stage: test
  services:
    - mongo:latest
  script:
    - ruby simpletest.rb

test_integration_job:    # интегрированные тесты
  stage: test
  script:
    - echo 'Testing 2'

deploy_dev_job:         # деплой в дев
  stage: review
  script:
    - echo 'Deploy'
  environment:          # разворачиваем окружение 
    name: dev
    url: http://dev.example.com

branch review:          # ветка ревью 
  stage: review         
  script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
  environment:
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except:
    - master

staging:
  stage: stage
  when: manual   # говорит о том, что job должен быть запущен человеком из UI
  only:
    - /^\d+\.\d+.\d+/   # директива, которая не позволит нам выкатить на staging и production код,
                        # не помеченный с помощью тэга в git
                        # описывает список условий, которые должны быть
                        # истинны, чтобы job мог запуститься. Регулярное выражение слева
                        # означает, что должен стоять semver тэг в git, например, 2.4.10
  script:
    - echo 'Deploy'
  environment:
    name: stage
    url: https://beta.example.com

production:
  stage: production
  when: manual
  only:
    - /^\d+\.\d+.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: production
    url: http://example.com
```
##### Изменение без указания тэга запустят пайплайн без job staging и production
##### Изменение, помеченное тэгом в git запустит полный пайплайн

```bash
git commit -a -m ‘#4 add logout button to profile page’
git tag 2.4.10
git push gitlab2 docker-7 --tags
```
### Динамические окружения

##### Gitlab CI позволяет определить динамические окружения, это мощная функциональность
##### позволяет вам иметь выделенный стенд для, например, каждой feature-ветки в git.
##### Определяются динамические окружения с помощью переменных, доступных в .gitlab-ci.yml

##### Этот job определяет динамическое окружение для каждой ветки в репозитории, кроме ветки master

```yamlex
branch review:
stage: review
script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
environment:
name: branch/$CI_COMMIT_REF_NAME
url: http://$CI_ENVIRONMENT_SLUG.example.com
only:
- branches
except:
- master
```

Теперь, на каждую ветку в git отличную от master Gitlab CI будет определять новое окружение.



# Homework 19

## Устройство Gitlab CI.
## Построение процесса непрерывной интеграции

### Инсталляция Gitlab

#### Создаем виртуальную машину в terraform

#####1. Нам потребуется создать в Google Cloud новую виртуальную машину со следующими параметрами

 - 1 CPU
 - 3.75GB RAM
 - 50-100 GB HDD
 - Ubuntu 16.04
 
 ```hcl-terraform
 
 # Подключаемся к гуглу к нашему проекту в регионе eur
provider "google" {
  version = "1.4.0"
  project = "${var.project}"
  region  = "${var.region}"
}

# Подключение SSH ключей для пользователя asomirl 
resource "google_compute_project_metadata" "ssh-asomirl" {
  metadata {
    ssh-keys = "${var.gitlab_admin}:${file(var.public_key_path)}"
  }
}

# Создаём в west-1b машину n1-standard-1	Standard machine type with 1 virtual CPU and 3.75 GB of memory.
resource "google_compute_instance" "gitlab" {
  name         = "gitlab"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
# Прибавили теги, чтобы ходить по SSH  
  tags         = ["docker-host", "default-allow-ssh"]

  # определение загрузочного диска 50Gb
  boot_disk {
    initialize_params {
# По умолчанию "ubuntu-1604-lts"    
      image = "${var.disk_image}"
      size  = 50
    }
  }
  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network = "default"

    # использовать ephemeral IP для доступа из Интернет
    access_config {}
  }
  # включаем подключение по ssh с путём к приватному ключу
  connection {
    type        = "ssh"
    user        = "${var.gitlab_admin}"
    agent       = false
    private_key = "${file(var.private_key_path)}"
  }
}

# Создание правила для firewall открываем для начала все порты и протокол ICMP
resource "google_compute_firewall" "docker-host-allow" {
  name = "docker-host-allow"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применимо для инстансов с тегом …
  target_tags = ["docker-host"]
}

# Создаём внешний адрес для машины
resource "google_compute_address" "gitlab_ip" {
  name = "gitlab-ip"
}

# Открываем порт 22
resource "google_compute_firewall" "firewall_ssh" {
  name    = "gitlab-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = "${var.source_ranges}"
}
```
##### 2. Затем ипортируем правило для терраформа доступ по умолчанию к SSH
В папке terraform-gitlab выполняем
```bash
$ terraform import google_compute_firewall.firewall_ssh defaultallow-ssh
``` 

#### Настраиваем виртуальную Машину с помощью Ansible

В файле inventory указываем имя хоста gitlab и его ip, 

```buildoutcfg
gitlab ansible_host=35.195.130.13
```
Также ip внесём в /roles/gitlab/defaults/main.yml, там же укажем имя нашего пользователя и папку для установки GitLab

```yamlex
deploy_user: asomirl
gitlab_ip: 35.195.130.13
gitlab_folder: /srv/gitlab
```

##### 3. Нам необходимо установить докер и докер композ. Из-за присущей лени мы тупо скачиваем ansible роль, которая ставит обадва сразу:

В папке с ролями выполняем скачивание роли ansible-galaxy nickjj.docker

```bash
ansible-galaxy install nickjj.docker -p ./ --force
```



##### 4. Создадим роль gitlab с готовой структурой папок

```bash
ansible-galaxy init gitlab
```
##### 5. В Роли gitlab в тасках добавляем установку Python и обновляшечки:

```yamlex
# tasks file for gitlab/
  - name: Install python for Ansible
    raw: test -e /usr/bin/python || (apt -y update && apt install -y python-minimal && apt install -y python-apt )
    become: true
    changed_when: false
```

##### 6. После тестирования и попытки запускать наш докер контейнер выпадает ошибка отсутствия docker-py, поэтому было принято ставить докер и пипы вручную.
В файле install_pip.yml устанавливаем необходимые нам пипули с хтопом, гитом на всякий, питошами. Также указываем нашего пользователя asomirl как деплой юзверя

```yamlex
# Examples from Ansible Playbooks
- name: Install base packages
  apt: name={{ item }} state=installed
  with_items:
    - htop #чтобы было удобно следить за установкой гитлаба
    - git # на всякий пожарный, чтобы выкачивать всякие нужные штуки из гита
    - python-pip # без этого ничего не работает
    - python3-pip # так и не понял, нужна ли 3 версия, паходу разберёмся
  tags:
    - packages

- name: Upgrade pip # обновляем пипы на самые последние версии
  pip: name=pip state=latest
  tags:
    - packages

- name: Create user
  user:
    name: "{{ deploy_user }}" # создадим нашего пользователя на серваке на всякие пожарные 
    comment: "Used to deploy Gitlab"
    state: present
```
##### 7. Создаём папочки для конфигов, логов и данных нашего гитлаба из-под нашего пользючонка:

create_folders.yml
```yamlex
  - name: Creates directoryes
    file:
      path: "{{ gitlab_folder }}/config"
      path: "{{ gitlab_folder }}/data"
      path: "{{ gitlab_folder }}/logs"
      state: directory
      owner: "{{ deploy_user }}"
      group: "{{ deploy_user }}"
```

##### 8. Ставим докер ручками как взрослые мальчики: 

install_docker.yml

```yamlex
- name: ensure repository key is installed
  apt_key:
    id: "58118E89F3A912897C070ADBF76221572C52609D"
    keyserver: "hkp://p80.pool.sks-keyservers.net:80"
    state: present

- name: ensure docker registry is available
  # For Ubuntu 16.04 LTS, use this repo instead:
  apt_repository: repo='deb https://apt.dockerproject.org/repo ubuntu-xenial main' state=present

- name: ensure docker and dependencies are installed
  apt: name=docker-engine update_cache=yes

- service: name=docker state=restarted
```

##### 9. Туда же и жареный хряк. То есть докер-композ (ставим с помощью Пипы, чтобы больше не ругался): 

install_docker_compose.yml

```yamlex
- name: Install docker python module
  pip:
    name: "docker-compose"
```

##### 10. Создаём ниндзя-темплейт docker-compose.yml.j2

```yamlex
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'http://{{ gitlab_ip }}' # эту штуку берём из папки дефолтс
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'
```
##### 11. ...и копируем его содержимое на сервер гитлаб в приготовленную папку /srv/gitlab/ в файл docker-compose.yml

omnibus.yml

```yamlex
- name: Change mongo config file
  template:
    src: templates/docker-compose.yml.j2
    dest: /srv/gitlab/docker-compose.yml
    mode: 0644
```

##### 12. И запускаем в докер-композе наш docker-compose.yml

compose.yml

```yamlex
- name: docker-compose via ansible docker_service
  tags: "docker"
  docker_service:
    files: docker-compose.yml
    project_src: /srv/gitlab/
    project_name: "gitlab-service"
```

##### 13. Инклюдим все наши файлики в файл main.yml в папке tasks:

```yamlex
 - include: install_py.yml
 - include: install_pip.yml
 - include: create_folders.yml
 - include: install_docker.yml
 - include: install_docker_compose.yml
 - include: omnibus.yml
 - include: compose.yml
```


#### Запускаем развёртывание GitLab

##### 14. Запускаем из папки gitlab-terraform создание виртуальной машины для GitLab

```bash
terraform apply
```

##### 15. Запускаем конфигурирование и установку необоходимых пакетов и компонентов для GitLab с помощью Ansible:

```bash
cd ~/asomir_microservices/ansible-gitlab/roles
ansible-playbook gitlab.yml --vv
```

##### 16. И бешено радуемся установке. Пока ставится, мы заходим по ssh на созданную Машину GitLab запускаем htop и радуемся циферкам.

```bash
ssh asomirl@35.195.130.13
```

```bash
htop
```
##### 17. Переходим в браузере по айпи 35.195.130.13 и через некоторое время видим морду лисы. Вводим дважды придуманный пароль, затем вводим имя root и этот пароль, попадаем на приветственную Страницу гитлаба

### Настройки GitLab

#### Создаём проект в GitLab

##### 18. Создали группу homework и в ней новый проект example.
##### 19. Добавили remote в asomir_microservices

```bash
git checkout -b docker-6
git remote add gitlab http://35.195.130.13/homework/example.git
git push gitlab docker-6
```
##### 20. ДоБавили в репозиторий файл .gitlab-ci.yml

```yamlex
stages:
  - build
  - test
  - deploy

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  script:
    - echo 'Testing 1'

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_job:
  stage: deploy
  script:
    - echo 'Deploy'
```

И запушили его в гитлаб в наш проект

```bash
git add .gitlab-ci.yml
git commit -m 'add pipeline definition'
git push gitlab docker-6
```

##### 21. ПоЛучили токен 

```buildoutcfg
Specify the following URL during the Runner setup: http://35.195.130.13/
Use the following registration token during setup: qhRTVTPL5kmP4N9Tx5_U
```

##### 22. Выполнем команду на сервере GitLab:

```bash
sudo docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```
##### 23. Регистриуем Runner, это можно сделать командой

```bash
docker exec -it gitlab-runner gitlab-runner register
```

и отвечаем на вопросы: 

```bash
Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
http://35.195.130.13/
Please enter the gitlab-ci token for this runner:
qhRTVTPL5kmP4N9Tx5_U
Please enter the gitlab-ci description for this runner:
[38689f5588fe]: my-runner
Please enter the gitlab-ci tags for this runner (comma separated):
linux,xenial,ubuntu,docker
Whether to run untagged builds [true/false]:
[false]: true
Whether to lock the Runner to current project [true/false]:
[true]: false
Please enter the executor:
docker
Please enter the default Docker image (e.g. ruby:2.1):
alpine:latest
Runner registered successfully.
```

В итоге в настройка появился новый runner.


### Тестируем reddit

#### Добавим тестирование приложения reddit в pipeline

##### 24. Добавим исходный код reddit в репозиторий

```bash
 git clone https://github.com/express42/reddit.git && rm -rf ./reddit/.git
 git add reddit/
 git commit -m “Add reddit app”
 git push gitlab docker-6
```

##### 25. Изменим описание пайплайна в .gitlab-ci.yml

```yamlex
image: ruby:2.4.2

stages:
  - build
  - test
  - deploy

variables:
DATABASE_URL: 'mongodb://mongo/user_posts'
before_script:
  - cd reddit
  - bundle install

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  services:
    - mongo:latest
  script:
    - ruby simpletest.rb

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_job:
  stage: deploy
  script:
    - echo 'Deploy'
```

##### 26. Создали в папке reddit файл simpletest.rb на который ссылается pipeline

```yamlex
require_relative './app'
require 'test/unit'
require 'rack/test'

set :environment, :test

class MyAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_get_request
    get '/'
    assert last_response.ok?
  end

```

##### 27. В Gemfile добавили gem 'rack-test'

reddit\Gemfile

```python
source 'https://rubygems.org'

gem 'sinatra'
gem 'haml'
gem 'bson_ext'
gem 'bcrypt'
gem 'puma'
gem 'mongo'
gem 'json'
gem 'rack-test'

group :development do
    gem 'capistrano',         require: false
    gem 'capistrano-rvm',     require: false
    gem 'capistrano-bundler', require: false
    gem 'capistrano3-puma',   require: false
end

```

Теперь на каждое изменение в коде приложения будет запущен тест.

##### 28. Пушим всё в ГитЛаб и набюдаем, как ревьюверы whitew1nd (Yury Ignatov) и postgred (Andrey Aleksandrov) активно фейспалмят! 

## Задача со звездой 

### Интеграция GitLab в Slack

#### Настраиваем WebHook

##### 1. Идём по ссылке https://devops-team-otus.slack.com/apps Ищем Incoming Webhook - выбираем Add Configuration

##### 2. Выбираем канал, куда мы хотим получать сообщения или создаём новый канал, нажимаем Add WebHooks Integration

##### 3. Меняем иконку на более удобоваримую Upload An Image. В поле Customize Name вводим имя пользователя, от которого будут приходить Эвенты. Копируем URL Webhook. Save Settings
https://hooks.slack.com/services/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
##### 4. Заходим в проект Example - Settings - Integration - Slack Notifications. Кликаем галочку Active, в тригерах #Push указываем название комнаты, куда будет приходить уведомление #alexander-akilin
Вставляем наш webhook, указываем username - Test And save Changes. Радуемся пришедшим нотификашкам.  


# Homework 17

## Работа с сетью в Docker

### None network driver

1. Запустим контейнер с использованием none-драйвера, с временем жизни 100 секунд, по истечении автоматически удаляется. В качестве образа используем joffotron/docker-net-tools, в него 
входят утилиты bind-tools, net-tools и curl.

```bash
docker run --network none --rm -d --name net_test joffotron/docker-net-tools -c "sleep 100"
docker exec -ti net_test ifconfig 
```

### Памятка

```markdown
В результате, видим:
• что внутри контейнера из сетевых интерфейсов существует
только loopback.
• сетевой стек самого контейнера работает (ping localhost), но без
возможности контактировать с внешним миром.
• Значит, можно даже запускать сетевые сервисы внутри такого
контейнера, но лишь для локальных экспериментов
(тестирование, контейнеры для выполнения разовых задач и
т.д.)
```


2. Запустили контейнер в сетевом пространстве docker-хоста

```bash
docker run --network host --rm -d --name net_test joffotron/docker-net-tools -c "sleep 100"
```

3. Вывод команды docker exec -ti net_test ifconfig 

```markdown
br-9847ceaf8390 Link encap:Ethernet  HWaddr 02:42:1A:94:FA:64  
          inet addr:172.18.0.1  Bcast:172.18.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:1aff:fe94:fa64%32531/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1731 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1795 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:145258 (141.8 KiB)  TX bytes:283122 (276.4 KiB)

docker0   Link encap:Ethernet  HWaddr 02:42:27:F2:53:24  
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:27ff:fef2:5324%32531/64 Scope:Link
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:18460 errors:0 dropped:0 overruns:0 frame:0
          TX packets:28983 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:1440883 (1.3 MiB)  TX bytes:346814939 (330.7 MiB)

ens4      Link encap:Ethernet  HWaddr 42:01:0A:84:00:02  
          inet addr:10.132.0.2  Bcast:10.132.0.2  Mask:255.255.255.255
          inet6 addr: fe80::4001:aff:fe84:2%32531/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1460  Metric:1
          RX packets:146266 errors:0 dropped:0 overruns:0 frame:0
          TX packets:112334 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:908455582 (866.3 MiB)  TX bytes:254880160 (243.0 MiB)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1%32531/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:151209 errors:0 dropped:0 overruns:0 frame:0
          TX packets:151209 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:20506793 (19.5 MiB)  TX bytes:20506793 (19.5 MiB)

veth09faf80 Link encap:Ethernet  HWaddr 92:7D:D2:89:4A:BA  
          inet6 addr: fe80::907d:d2ff:fe89:4aba%32531/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:20324 errors:0 dropped:0 overruns:0 frame:0
          TX packets:10393 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:1922371 (1.8 MiB)  TX bytes:3072704 (2.9 MiB)

veth70277fa Link encap:Ethernet  HWaddr 5E:74:D5:EE:84:5B  
          inet6 addr: fe80::5c74:d5ff:feee:845b%32531/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:35274 errors:0 dropped:0 overruns:0 frame:0
          TX packets:70262 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:10678546 (10.1 MiB)  TX bytes:6665213 (6.3 MiB)

vethda70fe7 Link encap:Ethernet  HWaddr 9E:6E:BB:55:B3:17  
          inet6 addr: fe80::9c6e:bbff:fe55:b317%32531/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:49921 errors:0 dropped:0 overruns:0 frame:0
          TX packets:25008 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:4742482 (4.5 MiB)  TX bytes:7615475 (7.2 MiB)

vethe3618d9 Link encap:Ethernet  HWaddr A2:15:EC:B9:20:A0  
          inet6 addr: fe80::a015:ecff:feb9:20a0%32531/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:70 errors:0 dropped:0 overruns:0 frame:0
          TX packets:110 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:15456 (15.0 KiB)  TX bytes:14755 (14.4 KiB)

```

Вывод команды docker exec -ti net_test ifconfig 

```markdown
br-9847ceaf8390 Link encap:Ethernet  HWaddr 02:42:1a:94:fa:64  
          inet addr:172.18.0.1  Bcast:172.18.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:1aff:fe94:fa64/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1731 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1795 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:145258 (145.2 KB)  TX bytes:283122 (283.1 KB)

docker0   Link encap:Ethernet  HWaddr 02:42:27:f2:53:24  
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:27ff:fef2:5324/64 Scope:Link
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:18460 errors:0 dropped:0 overruns:0 frame:0
          TX packets:28983 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:1440883 (1.4 MB)  TX bytes:346814939 (346.8 MB)

ens4      Link encap:Ethernet  HWaddr 42:01:0a:84:00:02  
          inet addr:10.132.0.2  Bcast:10.132.0.2  Mask:255.255.255.255
          inet6 addr: fe80::4001:aff:fe84:2/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1460  Metric:1
          RX packets:146332 errors:0 dropped:0 overruns:0 frame:0
          TX packets:112405 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:908469183 (908.4 MB)  TX bytes:254894834 (254.8 MB)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:151209 errors:0 dropped:0 overruns:0 frame:0
          TX packets:151209 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:20506793 (20.5 MB)  TX bytes:20506793 (20.5 MB)

veth09faf80 Link encap:Ethernet  HWaddr 92:7d:d2:89:4a:ba  
          inet6 addr: fe80::907d:d2ff:fe89:4aba/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:20364 errors:0 dropped:0 overruns:0 frame:0
          TX packets:10413 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:1926171 (1.9 MB)  TX bytes:3078804 (3.0 MB)

veth70277fa Link encap:Ethernet  HWaddr 5e:74:d5:ee:84:5b  
          inet6 addr: fe80::5c74:d5ff:feee:845b/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:35344 errors:0 dropped:0 overruns:0 frame:0
          TX packets:70402 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:10699896 (10.6 MB)  TX bytes:6678513 (6.6 MB)

vethda70fe7 Link encap:Ethernet  HWaddr 9e:6e:bb:55:b3:17  
          inet6 addr: fe80::9c6e:bbff:fe55:b317/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:50021 errors:0 dropped:0 overruns:0 frame:0
          TX packets:25058 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:4751982 (4.7 MB)  TX bytes:7630725 (7.6 MB)

vethe3618d9 Link encap:Ethernet  HWaddr a2:15:ec:b9:20:a0  
          inet6 addr: fe80::a015:ecff:feb9:20a0/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:70 errors:0 dropped:0 overruns:0 frame:0
          TX packets:110 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:15456 (15.4 KB)  TX bytes:14755 (14.7 KB)

```

Видим, что значения совпадают, кроме того, что в первом случае сетевуха называется s4, во втором ens4

4. Запустили docker run --network host -d nginx несколько раз, а контейнер всё равно один запущен. Это фишка, а не баг.

5. На docker-host машине выполнили команду:

```bash
> sudo ln -s /var/run/docker/netns /var/run/netns

```
Теперь можно просматривать существующие неймспейсы с помощью

```bash
> sudo ip netns
```

#### Примечание: ip netns exec <namespace> <command> - позволит выполнять команды в выбранном namespace



# Homework 16

### Новая структура репозитория
• Теперь наше приложение состоит из трех компонент:
• post-py - сервис отвечающий за написание постов \
• comment - сервис отвечающий за написание комментариев \
• ui - веб-интерфейс, работающий с другими сервисами


#### 1. Dockerfile post-py
```docker
FROM python:3.6.0-alpine

WORKDIR /app
ADD . /app

RUN pip install -r /app/requirements.txt

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
```
#### 2. ./comment/Dockerfile

```docker
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
COPY . $APP_HOME
ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments
CMD ["puma"]
```

#### 3.  ./ui/Dockerfile

```docker
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME
ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292
CMD ["puma"]
```
#### 4. Скачали образ монги последней версии:

```bash
> docker pull mongo:latest
``` 
#### 5. Запустили образа с сервисами

```bash
> docker build -t <your-dockerhub-login>/post:1.0 ./post-py
> docker build -t <your-dockerhub-login>/comment:1.0 ./comment
> docker build -t <your-dockerhub-login>/ui:1.0 ./ui
```
Сборка ЮИ началась не с первого шага, потому как предыдущие шаги уже были проделаны при старте Каммента 
Памятка: 

Что мы сделали?
• Создали bridge-сеть для контейнеров, так как сетевые
алиасы не работают в сети по умолчанию ( о сетях в
Docker мы еще поговорим на следующем занятии)
• Запустили наши контейнеры в этой сети
• Добавили сетевые алиасы контейнерам
• Сетевые алиасы могут быть использованы для сетевых
соединений, как доменные имена

#### 6. Поменяли  ./ui/Dockerfile - собираем образ с последней убунтой

````docker
FROM ubuntu:16.04
RUN apt-get update \
 && apt-get install -y ruby-full ruby-dev build-essential \
 && gem install bundler --no-ri --no-rdoc
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME
ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292
CMD ["puma"]
````

И пометили его как версия 2 

```bash
> docker build -t <your-login>/ui:2.0 ./ui
```
#### 7. Прикончили старые версии контейнеров и создадим новые с новой версией ЮИ

```bash
> docker kill $(docker ps -q)
> docker run -d --network=reddit \
 --network-alias=post_db --network-alias=comment_db mongo:latest
> docker run -d --network=reddit \
 --network-alias=post <your-dockerhub—login>/post:1.0
> docker run -d --network=reddit \
 --network-alias=comment <your-dockerhub-login>/comment:1.0
> docker run -d --network=reddit \
 -p 9292:9292 <your-dockerhub-login>/ui:2.0
```
#### 8. Создадим docker volume
```bash
> docker volume create reddit_db
```

и подключим его к базе данных, Выключив предварительно старые копии контейнеров

```bash
> docker kill $(docker ps -q)
> docker run -d --network=reddit —network-alias=post_db \
 --network-alias=comment_db -v reddit_db:/data/db mongo:latest
> docker run -d --network=reddit \
 --network-alias=post <your-login>/post:1.0
> docker run -d --network=reddit \
 --network-alias=comment <your-login>/comment:1.0
> docker run -d --network=reddit \
 -p 9292:9292 <your-login>/ui:2.0
```

#### 9. Теперь посты сохраняются после пересобирания образов. 


# Homework 15

####1. Создали новый проект в GCP docker-194414 и создали докер хост: 

```bash
> docker-machine create --driver google \
--google-project docker-194414 \
--google-zone europe-west1-b \
--google-machine-type g1-small \
--google-machine-image $(gcloud compute images list --filter ubuntu-1604-lts --uri) \
docker-host
```
#### 2. Проверяем, что наш Docker-хост успешно создан...

```bash
docker-machine ls
```

#### 3. Подключаемся к нему

```bash
eval $(docker-machine env docker-host)
```
#### 4. Создаём 4 файла

* Dockerfile - текстовое описание нашего образа

```docker
FROM ubuntu:16.04 # Создаём имидж из последней убунты

RUN apt-get update # Обновили пакеты
RUN apt-get install -y mongodb-server ruby-full ruby-dev build-essential git # Установили монго и руби
RUN gem install bundler
RUN git clone https://github.com/Artemmkin/reddit.git # Скачали в контейнер реддит

# Копируем в контейнер файлы конфигурации
COPY mongod.conf /etc/mongod.conf
COPY db_config /reddit/db_config
COPY start.sh /start.sh


# Устанавливаем зависимости и запускаем скрипт настройки
RUN cd /reddit && bundle install
RUN chmod 0777 /start.sh

# Стартуем сервис при старте контейнера
CMD ["/start.sh"]
```
• mongod.conf - преподготовленный конфиг для mongodb

```buildoutcfg
# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  bindIp: 127.0.0.1
```
• db_config - содержит переменную со ссылкой на mongodb

```buildoutcfg
DATABASE_URL=127.0.0.1
```

• start.sh - скрипт запуска приложения

```bash
#!/bin/bash
/usr/bin/mongod --fork --logpath /var/log/mongod.log --config /etc/mongodb.conf
source /reddit/db_config
cd /reddit && puma || exit
```

#### 5. Собираем контейнер с тегом reddit:latest, точка в конце = путь до Докер-контекста (?)

```bash
docker build -t reddit:latest .
```

#### 6. Смотрим набор имажев: 

```bash
docker images -a
``` 

```docker
REPOSITORY           TAG                 IMAGE ID            CREATED             SIZE
<none>               <none>              6d5f15dea66c        24 minutes ago      682MB
asomir/otus-reddit   1.0                 3ddd4d70e49f        24 minutes ago      682MB
reddit               latest              3ddd4d70e49f        24 minutes ago      682MB
<none>               <none>              33961ea15acd        24 minutes ago      682MB
<none>               <none>              fdd30df927aa        24 minutes ago      650MB
<none>               <none>              1b07d9acf2a1        24 minutes ago      650MB
<none>               <none>              fd5c5ee9c266        24 minutes ago      650MB
<none>               <none>              99eb7073e4ab        24 minutes ago      650MB
<none>               <none>              29feb728d310        24 minutes ago      650MB
<none>               <none>              b21f1e029915        24 minutes ago      647MB
<none>               <none>              28f07a2ab0c6        26 minutes ago      151MB
ubuntu               16.04               0458a4468cbc        2 weeks ago         112MB

```

#### 7. Запускаем наш контейнер 

```bash
docker run --name reddit -d --network=host reddit:latest
```

#### 8. Разрешим входящий трафик на порт 9292

```bash
gcloud compute firewall-rules create reddit-app \
--allow tcp:9292 --priority=65534 \
--target-tags=docker-machine \
--description="Allow TCP connections" \
--direction=INGRESS
```

#### 9. Пошли по ссылке http://35.205.170.223:9292/ - порадовались! 
#### 10. Пошли на докер хаб 

```bash
docker login
```

#### 11. Загрузили на докер хаб нашу образюлю

```bash
docker tag reddit:latest asomir/otus-reddit:1.0
docker push asomir/otus-reddit:1.0
```

#### 12. Мы прекрасны. И не наркоманы! 



# HomeWork 14



```bash
docker images
```
```bash
REPOSITORY               TAG                 IMAGE ID            CREATED             SIZE
asomir/ubuntu-tmp-file   latest              46a62528372b        9 hours ago         112MB
asomir/nginx-tmp-file    latest              5ecfc7c8efbd        9 hours ago         108MB
ubuntu                   16.04               0458a4468cbc        10 days ago         112MB
ubuntu                   latest              0458a4468cbc        10 days ago         112MB
nginx                    latest              3f8a4339aadd        5 weeks ago         108MB
hello-world              latest              f2a91732366c        2 months ago        1.85kB

```

* Дз со свездой 
Выполним команду docker inspect 3f8a4339aadd > docker_image
и docker inspect 979cef3539af > docker_container
и сравним их вывод.
Когда мы инспектим контейнер, то видим там описани его состояния, настроек сети : 

```markdown
"State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 3850,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2018-02-05T05:34:44.361548395Z",
            "FinishedAt": "0001-01-01T00:00:00Z"

 "Gateway": "172.17.0.1",
        "IPAddress": "172.17.0.3",
        "IPPrefixLen": 16,
        "IPv6Gateway": "",
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "MacAddress": "02:42:ac:11:00:03",
        "DriverOpts": null
        
        
``` 

Когда мы инспектим Image, мы видим архитектуру

```markdown
"Architecture": "amd64",
"Os": "linux",
"Size": 108492271,
"VirtualSize": 108492271,
"GraphDriver": {
```

Config нашёлся в обоих местах
image:
```markdown
"Config": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "ExposedPorts": {
                "80/tcp": {}
            },
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "NGINX_VERSION=1.13.8-1~stretch",
                "NJS_VERSION=1.13.8.0.1.15-1~stretch"
            ],
            "Cmd": [
                "nginx",
                "-g",
                "daemon off;"
            ],
```

container

```markdown
"Config": {
            "Hostname": "979cef3539af",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "ExposedPorts": {
                "80/tcp": {}
            },
            "Tty": true,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "NGINX_VERSION=1.13.8-1~stretch",
                "NJS_VERSION=1.13.8.0.1.15-1~stretch"
            ],
            "Cmd": [
                "nginx",
                "-g",
                "daemon off;"
            ],
```

Итак, делаем вывод, что контейнер имеет состояние, конфигурацию, маунты, конфиг. В имидже также присутствует конфиг, метаинформация и информация об архитектуре.

