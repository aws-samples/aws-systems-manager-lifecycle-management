- hosts: all
  become: true

  tasks:
  - name: configure mongo yum repo
    yum_repository:
      description: MongoDB Repository
      name: mongodb-org-4.0
      baseurl: https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/4.0/x86_64/
      gpgcheck: 1
      gpgkey: https://www.mongodb.org/static/pgp/server-4.0.asc

  - name: install mongo
    yum: name=mongodb-org state=present

  - name: Create data FS
    filesystem:
      fstype: ext4
      dev: /dev/nvme1n1

  - name: Create logs FS
    filesystem:
      fstype: ext4
      dev: /dev/nvme2n1

  - name: Create data directory
    file:
      path: /opt/data
      state: directory
      owner: mongod 
      group: mongod 

  - name: Create log directory
    file:
      path: /opt/logs
      state: directory
      owner: mongod 
      group: mongod 
      
  - name: Mount data volume
    mount:
      path: /opt/data
      src: /dev/nvme1n1
      fstype: ext4
      state: mounted

  - name: Mount logs volume
    mount:
      path: /opt/logs
      src: /dev/nvme2n1
      fstype: ext4
      state: mounted

  - name: configure system settings, file descriptors and number of threads
    pam_limits:
      domain: mongod
      limit_type: "{{item.limit_type}}"
      limit_item: "{{item.limit_item}}"
      value: "{{item.value}}"
    with_items:
      - { limit_type: '-', limit_item: 'fsize', value: unlimited }
      - { limit_type: '-', limit_item: 'cpu', value: unlimited }
      - { limit_type: '-', limit_item: 'nofile', value: 64000 }
      - { limit_type: '-', limit_item: 'nproc', value: 64000 }
      - { limit_type: '-', limit_item: 'memlock', value: unlimited }
      - { limit_type: '-', limit_item: 'as', value: unlimited }
  - name: reload settings from all system configuration files
    shell: sysctl --system

  - name: Edit MongoDB config file for logs
    lineinfile:
      path: /etc/mongod.conf
      regexp: 'mongod\.log'
      line: '  path: /opt/logs/mongod.log'
      backup: true
  - name: Edit MongoDB config file for data
    lineinfile:
      path: /etc/mongod.conf
      regexp: 'dbPath'
      line: '  dbPath: /opt/data'
      backup: true
  - name: Edit MongoDB config file for replication
    lineinfile:
      path: /etc/mongod.conf
      regexp: 'replication:'
      line: 'replication:'
      backup: true
  - name: Query region 
    shell: /usr/bin/curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}'
    args:
      warn: False
    register: region_out
  - name: Look up region
    set_fact:
      Region: "{{ region_out.stdout }}"
  - name: Create root AWS config folder
    file:
      path: /root/.aws
      state: directory
  - name: Set default region
    lineinfile:
      path: /root/.aws/config
      line: '[default]'
      create: yes
  - name: Set default region header
    lineinfile:
      path: /root/.aws/config
      line: 'region = {{ Region }}'
  - name: Look up bind IP
    set_fact:
      BindIP: "{{ lookup('aws_ssm', '/{{ Project }}/{{ Environment }}/{{ Role }}/eip/{{ ID }}') }}"
  - name: Set repl set name
    set_fact:
      ReplSetName: "{{ Project }}_{{ Environment }}_{{ Role }}"
  - debug: msg="{{ ReplSetName }}"
  - debug: msg="{{ BindIP }}"
  - debug: msg="{{ Region }}"
  - name: Edit MongoDB config file for replica set name
    lineinfile:
      path: /etc/mongod.conf
      line: '  replSetName: {{ ReplSetName }}'
      insertafter: '^replication:'
      backup: true
  - name: Edit MongoDB config file for bind IP
    lineinfile:
      path: /etc/mongod.conf
      regexp: '^  bindIp:'
      line: '  bindIp: localhost,{{ BindIP }}'
      backup: true

  - name: Pause for mongo to stabilize
    pause:
      seconds: 60

  - name: Start service mongod, if not started
    service:
      name: mongod
      state: started
      enabled: yes
    register: mongo_result
    retries: 3
    delay: 30
    until: mongo_result is success

  - name: Show mongod output
    debug: var=mongo_result.stdout
  - name: Show mongod error 
    debug: var=mongo_result.stderr
