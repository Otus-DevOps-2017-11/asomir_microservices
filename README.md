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

