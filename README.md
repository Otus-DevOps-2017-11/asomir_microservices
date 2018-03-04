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

