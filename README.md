# Homework-27

## Docker swarm

### Строим Swarm Cluster


##### Создадим машину master-1












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

104.154.181.55

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

