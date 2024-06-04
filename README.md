# Grafana and Telegraf Metrics Monitoring  System

Grafana is an open-source platform for monitoring and observability, primarily used to visualize time series data. It allows users to create and share dynamic dashboards, providing powerful and flexible visual representations of data.

Telegraf is the server agent for collecting, processing, aggregating and writing metrics to InfluxDB.

Grafana supports various data sources such as Prometheus, Graphite and OpenTSDB. In this lab we'll use InfluxDB as our preferred data source.

InfluxDB is used as a data source for Grafana due to its high performance and scalability in handling large volumes of time-stamped data.

![](https://github.com/odennav/grafana-telegraf-metrics-monitoring-system/blob/main/docs/Grafana-telegraf-influxdb.png)

-----

## Getting Started

- Provision Servers

- User Configuration 

- Setup InfluxDB v2

- Setup Telegraf

- Setup Grafana

- Create Grafana Data Source

- Import System Dashboard

- Ansible Installation and Setup

- Add Remote Hosts to Grafana Dasboard


## Provision Servers

Install Vagrant

If you haven't installed Vagrant, download it [here](https://developer.hashicorp.com/vagrant/install) and follow the installation instructions for your OS.

If you encounter an issue with Windows, you might get a blue screen upon attempt to bring up a VirtualBox VM with Hyper-V enabled.

To use VirtualBox on Windows, ensure Hyper-V is not enabled. Then turn off the feature with the following Powershell commands:

```bash
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
bcdedit /set hypervisorlaunchtype off
```
After reboot of your local machine, run:

```bash
vagrant up cs1
vagrant ssh cs1
```
-----

## User Configuration 

**Add New User**

We'll use `cs1` virtual machine as our build machine.

Change password for root user
```bash
sudo passwd
```

Switch to root user. Add new user `odennav` to sudo group.
```bash
sudo useradd odennav
sudo usermod -aG wheel odennav
```

Notice the prompt to enter your user password. To disable password prompt for every sudo command, implement the following:

Add sudoers file for odennav-admin

```bash
echo "odennav ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/odennav
```

Ensure correct permissions for sudoers file
```bash
sudo chmod 0440 /etc/sudoers.d/odennav
sudo chown root:root /etc/sudoers.d/odennav
```

Create new password for `odennav` user
```bash
sudo passwd odennav
```

Test sudo privileges by switching to new user

```bash
su - odennav
sudo ls -la /root
```

To change the PermitRootLogin setting, modify the SSH server configuration file `/etc/ssh/sshd_config` as shown below:

```text
PermitRootLogin no
```

Restart the SSH service
```bash
sudo systemctl restart sshd.service
```

Please note you'll have to repeat this user setup for each server provisioned.

-----

## Setup InfluxDB v2

Install InfluxDB as a service with systemd as shown below:

Download and install the appropriate `.rpm` file

```bash
curl -LO https://download.influxdata.com/influxdb/releases/influxdb2-2.7.6-1.x86_64.rpm
sudo yum localinstall -y influxdb2-2.7.6-1.x86_64.rpm
```

Start and enable the InfluxDB service

```bash
sudo systemctl start influxdb.service
sudo systemctl enable influxdb.service
```

Installing the InfluxDB package creates a service file at `/lib/systemd/system/influxdb.service` to start InfluxDB as a background service on startup.

Verify the service is running

```bash
sudo systemctl status influxdb.service
```

**Setup Initial User of InfluxDB**

Implement the following:

- With InfluxDB running, visit `http://localhost:8086`.

- Click `Get Started`.

- Enter a `Username` for your initial user.

- Enter a `Password` and `Confirm Password` for your user.

- Enter your initial `Organization Name`.

- Enter your initial `Bucket Name`.

- Click `Continue`.

- Copy the provided `operator API token` and store it for safe keeping.

Your InfluxDB instance is now initialized.

**Install Influx CLI**

The influx CLI is used to interact with and manage your InfluxDB instance.

Confirm the cpu architecture of your local machine to
```bash
uname -m
lscpu | grep Architecture
```

Download the influx CLI package from the command line.
```bash
sudo wget https://download.influxdata.com/influxdb/releases/influxdb2-client-2.7.5-linux-amd64.tar.gz
```

Unpackage the downloaded binary
```bash
tar xvzf ./influxdb2-client-2.7.5-linux-amd64.tar.gz
```

 Place the unpackaged influx executable in system $PATH
```bash
sudo cp ./influx /usr/local/bin/
```

Confirm influx client is available
```bash
influx version
```

**Create an All Access API token with influx CLI**

With the Operator token we can interact with InfluxDB, it's recommended to create an `All Access token` that is scoped to an organization, and then using this token to manage InfluxDB.

Use the influx auth create command to create an All Access token

```bash
influx auth create \
  --all-access \
  --host http://localhost:8086 \
  --org Treten \
  --token <YOUR_INFLUXDB_OPERATOR_TOKEN>
```

Copy the generated token and store it for safe keeping.


**Configure authentication credentials**

A connection configuration stores your credentials to avoid having to pass your InfluxDB API token with each influx command. 

It specifies connection configuration presets to switch between InfluxDB connection credentials.

Use the `All Access token` to interact with InfluxDB.

```bash
influx config create \
  --config-name odennav-config \
  --host-url http://localhost:8086 \
  --org Treten \
  --token <ALL ACCESS API_TOKEN> \
  --active
```

Authenticate with a username and password
```bash
influx config create \
  -n odennav-config \
  -u http://localhost:8086 \
  -p odennav:<PASSWORD> \
  -o Treten
```

Set the following environment variables
```bash
export INFLUX_HOST=localhost:8086
export INFLUX_ORG=Treten
export INFLUX_ORG_ID=<ORG_ID>
export INFLUX_TOKEN=<ALL ACCESS API_TOKEN>
```

-----

## Setup Telegraf

Use the yum package manager to install the latest stable version of Telegraf

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/influxdb.repo
[influxdb]
name = InfluxData Repository - Stable
baseurl = https://repos.influxdata.com/stable/\$basearch/main
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF
```

Install Telegraf from the repo

```bash
sudo yum install -y telegraf
```

The telegraf configuration file is installed at `/etc/telegraf/telegraf.conf`

Create a configuration file with default input and output plugins

```bash
telegraf config > /etc/telegraf/telegraf.conf
```

Configure the input plugins

   Search and uncomment the following plugins below to enable them in `telegraf.conf` file

```text
[[inputs.conntrack]]
[[inputs.internal]]
[[inputs.interrupts]]
[[inputs.linux_sysctl_fs]]
[[inputs.net]]
[[inputs.netstat]]
[[inputs.nstat]]
```


Start and enable Telegraf service

```bash
sudo systemctl start telegraf
sudo systemctl enable telegraf
```

Verify the Telegraf service is running

```bash
sudo systemctl status telegraf.service
```

Check databases in InfluxDB

```bash
influx bucket list
```

Look at metrics/tables stored in the telegraf database
```bash
influx query 'import "influxdata/influxdb/schema" schema.measurements(bucket: "telegraf")'
```

Check data from swap measurement table
```bash
influx query 'from(bucket: "telegraf")
  |> range(start: -1m)
  |> filter(fn: (r) => r._measurement == "swap")'
```

-----


## Setup Grafana

**Install Grafana**

To install Grafana from the RPM repository, complete the following steps:

```bash
wget -q -O gpg.key https://rpm.grafana.com/gpg.key
sudo rpm --import gpg.key
```

Use the yum package manager to install the latest stable version of Grafana
Add this to `/etc/yum/epos.d/grafana.repo`
```bash
cat << EOF | sudo tee /etc/yum/epos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
```

Install Grafana Enterprise
```bash
sudo yum install grafana-enterprise
```

To start the grafana service
```bash
sudo systemctl daemon-reload
sudo systemctl start grafana-server
```

To configure the Grafana server to start at boot
```bash
sudo systemctl enable grafana-server.service
```

To verify that the grafana service is running
```
sudo systemctl status grafana-server
```

-----

## Create Grafana Data Source

Open a web browser and connect to http://192.168.10.1:3000. Log in with the username of `admin` and the password of `admin`

Implement the following:

- Click on the gear icon in the menu bar on the left. It will take you to the Configuration page for Grafana

- Click on the `Add data sources` button

- Click on `InfuxDB` as your choice of time series database.

- Fill the `Settings` form as below:

  Name ----------------> InfluxDB-Telegraf
  
  Default--------------> Click to turn the selector on.

  Query Language ------> InfluxQL

  URL -----------------> http://localhost:8086

  Access --------------> Server (default)

  Database ------------> telegraf


Click the `Save & Test` button.

Now Grafana can access the metrics stored in InfluxDB.

-----

## Import System Dashboard

Hover over the plus sign in the menu on the left of your screen. It will expand into a menu when you hover over it.

From there, click on `Import`.

Implement the following:

- In the `Grafana dashboard URL or id` field, enter `13095` and click the "Load" button next to it.

An alternative is to import the JSON file for the dashboard.

To upload click `Upload JSON File` and navigate to '/grafana-metrics-monitoring-system/grafana templates/13095_System` in this repo. 

There are other templates available in the directory.

To view more dashboards, check [Grafana Labs](https://grafana.com/grafana/dashboards/)

- On the next screen in the `Select an InfluxDB data source` box, select `InfluxDB-Telegraf`. Then click on the `Import` button.

Now you should see a dashboard displaying system performance information for the grafana host.

Ensure to save the imported dasboard.

----- 

## Ansible Installation and Setup

The task of configuring a remote hosts as an icinga agents is repetitve.

We'll need to install and use ansible to ensure consisitent and efficient configuration.

**Install Ansible**

To install ansibe without upgrading current python version, we'll make use of the yum package manager.

```bash
sudo yum update
```

Install EPEL repository

```bash
sudo yum install epel-release
```

Verify installation of EPEL repository
```bash
sudo yum repolist
```

Install Ansible
```bash
sudo yum install ansible
```

Confirm installation
```bash
ansible --version
```

**Configure Ansible Vault**

Ansible communicates with target remote servers using SSH and usually we generate RSA key pair and copy the public key to each remote server, instead we'll use username and password credentials of odennav user.

This credentials are added to inventory host file but encrypted with ansible-vault

Ensure all IPv4 addresses and user variables of remote servers are in the inventory file as shown

View `ansible-vault/values.yml` which has the secret password

```bash
cat /grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/values.yml
```

Generate vault password file
```bash
openssl rand -base64 2048 > /grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/secret-vault.pass
```

Create ansible vault with vault password file
```bash
ansible-vault create /grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/values.yml --vault-password-file=/grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/secret-vault.pass
```

View content of ansible vault
```bash
ansible-vault view /grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/values.yml --vault-password-file=/grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/secret-vault.pass
```

Read ansible vault password from environment variable
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=/grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/secret-vault.pass
```

Confirm environment variable has been exported
```bash
export ANSIBLE_VAULT_PASSWORD_FILE
```

Test Ansible by pinging all remote servers in inventory list
```bash
ansible all -m ping
```

-----

## Add Remote Hosts to Grafana Dashboard

Provision other remote hosts with Vagrant and implement new user configuration.


Use ansible playbook `/ansible/deploy_telegraf/setup_telegraf.yml`
```bash
ansible-playbook -i inventory /grafana-telegraf-metrics-monitoring-system/ansible/deploy_telegraf/deploy_telegraf.yml -e @/grafana-telegraf-metrics-monitoring-system/ansible/ansible-vault/values.yml
```

Return to your web browser and reload the dashboard page.

At the top of your browser you should see a selector box for `Server`.  When you click on the word `Server` you will see the grafana VM, `cs1` as well as our newly added VMs.

-----

Enjoy!

