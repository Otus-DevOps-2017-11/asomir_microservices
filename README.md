# Homework 17

##### Подключаемся к ранее созданному docker host’у


> docker-machine ls


```markdown
NAME          ACTIVE   DRIVER   STATE     URL                         SWARM   DOCKER        ERRORS
docker-host   *        google   Running   tcp://35.205.170.223:2376           v18.02.0-ce   

```

> eval $(docker-machine env docker-host)

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

## Bridge network driver

##### 6. Создаём brige сеть в  docker

```bash
docker network create reddit --driver bridge
```
##### 7. Запускаем наш проект reddit с использованием brige-сети:

```bash
> docker run -d --network=reddit mongo:latest
> docker run -d --network=reddit asomir/post:1.0
> docker run -d --network=reddit asomir/comment:1.0
> docker run -d --network=reddit -p 9292:9292 asomir/ui:1.0
```
Идём по ссылке http://35.205.170.223:9292/ и получаем писей по губам.
Наши сервисы ищут друг друга по ДНС именам (внимательно читаем докерфайл), поэтому они ничерта не знают друг о друге.

##### 8. Присваиваем контейнерам имена или алиасы: 

```bash
> docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
> docker run -d --network=reddit --network-alias=post asomir/post:1.0
> docker run -d --network=reddit --network-alias=comment asomir/comment:1.0
> docker run -d --network=reddit -p 9292:9292 asomir/ui:1.0
```

Переходим по адресу http://35.205.170.223:9292 и радуемся постам.

##### 9. Убиваем все докер контейнеры 

> docker kill $(docker ps -q)

##### 10. Создаём докер сети для фронтэндв и бекэнда: 

> docker network create back_net —subnet=10.0.2.0/24
> docker network create front_net --subnet=10.0.1.0/24

##### 11. Запускаем сети в соответсвующих сетях

> docker run -d --network=front_net -p 9292:9292 --name ui asomir/ui:1.0
> docker run -d --network=back_net --name comment asomir/comment:1.0
> docker run -d --network=back_net --name post asomir/post:1.0
> docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest

Пошли на адрес http://35.205.170.223:9292/ и счастливо постим постики

## Docker-compose

##### 12. 
#####



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

