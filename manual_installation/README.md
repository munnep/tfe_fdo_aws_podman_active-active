# Manual steps

This document describes the manual steps for creating a TFE active/active cluster behind an application load balancer with an Autoscaling group which you can then connect to over the internet. The TFE is in a private subnet

See below diagram for how the setup is:
![](../diagram/diagram_tfe_active_mode.png)

# Create TFE airgap Autoscaling group with loadbalancer single instance
## network
- Create a VPC with cidr block ```10.238.0.0/16```  
![](media/20220912133108.png)  
- Create 4 subnets. 2 public subnets and 2 private subnet
    - patrick-public1-subnet (ip: ```10.238.1.0/24``` availability zone: ```eu-north-1a```)  
    - patrick-public2-subnet (ip: ```10.238.2.0/24``` availability zone: ```eu-north-1b```)  
    - patrick-private1-subnet (ip: ```10.238.11.0/24``` availability zone: ```eu-north-1a```)  
    - patrick-private2-subnet (ip: ```10.238.12.0/24``` availability zone: ```eu-north-1b```)  
![](media/20220912133359.png)    
![](media/20220912133414.png)    
- create an internet gateway and attach to VPC  
![](media/20220912133448.png)   
![](media/20220912133514.png)    
- create a nat gateway which you attach to ```patrick-public1-subnet```   
![](media/20220912133618.png)    
- create routing table for public  
![](media/20220912133707.png)    
   - edit the routing table for internet access to the internet gateway
   ![](media/20220912133804.png)    
- create routing table for private  
   ![](media/20220912133926.png)     
   - edit the routing table for internet access to the nat gateway  
   ![](media/20220912134020.png)     
- attach routing tables to subnets  
    - patrick-public-route to public subnets      
    ![](media/20220912134139.png)       
    - patrick-private-route to private subnet   
     ![](media/20220912134105.png)  
- create a security group that allows  
https    
port 5432 for PostgreSQL database    
6379 redis  
8201 vault  
![](media/20220912134534.png)  
- 

## Create the RDS postgresql instance
Creating the RDS postgreSQL instance to use with TFE instance

- PostgreSQL instance version 14  
![](media/20220912135024.png)   
![](media/20220912135037.png)    
![](media/20220912135050.png)    
![](media/20220912135110.png)    
![](media/20220912135124.png)    



endpoint: ```patrick-tfe-rds.cvwddldymexr.eu-north-1.rds.amazonaws.com```

# AWS to use
- create a bucket patrick-tfe-manual and patrick-tfe-software  
![](media/20220912135225.png)      
![](media/20220912135307.png)    
- upload the following files to patrick-tfe-software  
The certificate files created that will be downloaded at a later point to the machine

- create IAM policy to access the buckets from the created instance  
- create a new policy  
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::patrick-tfe-manual",
                "arn:aws:s3:::patrick-tfe-software",
                "arn:aws:s3:::*/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        }
    ]
}
```

- create a new role    
![](media/20220520124616.png)     
![](media/20220520124635.png)    
![](media/20220520124711.png)    

## Create a Redis environment

Get a elasticache Redis environment  
![](media/20220912155231.png)    
![](media/20220912155647.png)    
![](media/20220912155656.png)    
![](media/20220925140444.png)    
![](media/20220912155716.png)    
![](media/20220912155726.png)    
![](media/20220912155737.png)    
![](media/20220912155803.png)    
![](media/20220912155819.png)    



## certificates  
import certificates for patrick-tfe2.bg.hashicorp-success.com
![](media/20220520124850.png)      
![](media/20220520124941.png)      
![](media/20220925133852.png)      

# Launch a stepping stone instance

![](media/20220912141116.png)      

# Auto Launch scaling group

- Create an auto launch scaling group  
![](media/20220925105450.png)    
![](media/20220925105711.png)  
![](media/20220925112226.png)       
![](media/20220925112259.png)    

Change the values in the script to match the environment
```
#cloud-config
write_files:
  - path: /var/tmp/compose.yaml
    permissions: '0640'
    content: |
      version: "3.9"
      name: terraform-enterprise
      services:
        tfe:
          image: quay.io/hashicorp/terraform-enterprise:latest
          environment:
            TFE_LICENSE: ${tfe_license}
            TFE_HOSTNAME: "${dns_hostname}.${dns_zonename}"
            TFE_OPERATIONAL_MODE: "active-active"    
            TFE_ENCRYPTION_PASSWORD: "${tfe_password}"
            TFE_DISK_CACHE_VOLUME_NAME: $${COMPOSE_PROJECT_NAME}_terraform-enterprise-cache
            TFE_TLS_CERT_FILE: /etc/ssl/private/terraform-enterprise/cert.pem
            TFE_TLS_KEY_FILE: /etc/ssl/private/terraform-enterprise/key.pem
            TFE_TLS_CA_BUNDLE_FILE: /etc/ssl/private/terraform-enterprise/bundle.pem
            # Database settings.
            TFE_DATABASE_USER: "postgres"
            TFE_DATABASE_PASSWORD: "${rds_password}"
            TFE_DATABASE_HOST: "${pg_address}"
            TFE_DATABASE_NAME: "${pg_dbname}"
            TFE_DATABASE_PARAMETERS: sslmode=require
            # Object storage settings.
            TFE_OBJECT_STORAGE_TYPE: "s3"
            TFE_OBJECT_STORAGE_S3_REGION: ${region}
            TFE_OBJECT_STORAGE_S3_BUCKET: ${tfe_bucket}
            TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE: "true"
            # redis
            TFE_REDIS_HOST: ${redis_host}
            TFE_REDIS_USE_AUTH: false
            # /vault 
            TFE_VAULT_CLUSTER_ADDRESS: "https://PRIVATE_IP_ADDRESS_WILL_BE_PLACED_HERE:8201"
          cap_add:
            - IPC_LOCK
          read_only: true
          tmpfs:
            - /tmp
            - /var/run
            - /var/log/terraform-enterprise
          ports:
            - "80:80"
            - "443:443"
            - "8201:8201"
          volumes:
            - type: bind
              source: /var/run/docker.sock
              target: /var/run/docker.sock
            - type: bind
              source: ./certs
              target: /etc/ssl/private/terraform-enterprise
            - type: volume
              source: terraform-enterprise-cache
              target: /var/cache/tfe-task-worker/terraform
          deploy:
            restart_policy:
              condition: any
              delay: 5s
              window: 120s    
      
      volumes:
        terraform-enterprise-cache:
  - path: /var/tmp/install_software.sh 
    permissions: '0750'
    content: |
      #!/usr/bin/env bash
      # installation script for software
      
      # wait until archive is available. Wait until there is internet before continue
      until ping -c1 archive.ubuntu.com &>/dev/null; do
        echo "waiting for networking to initialise"
        sleep 3 
      done 
      
      # install monitoring tools
      apt-get update
      apt-get install -y ctop net-tools sysstat jq      
      
      # installation of the netdata tool for performance monitoring
      # Netdata will be listening on port 19999
      curl -sL https://raw.githubusercontent.com/automodule/bash/main/install_netdata.sh | bash
      
      # add public ssh key alvaro
      curl -sL https://raw.githubusercontent.com/kikitux/curl-bash/master/provision/add_github_user_public_keys.sh | GITHUB_USER=kikitux bash
      
      # add public ssh key patrick
      curl -sL https://raw.githubusercontent.com/kikitux/curl-bash/master/provision/add_github_user_public_keys.sh | GITHUB_USER=munnep bash
      
      # Set swappiness
      if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
      fi
      
      if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
        echo never > /sys/kernel/mm/transparent_hugepage/defrag
      fi
      
      # heavy swap vm.swappiness=80
      # no swap vm.swappiness=1

      echo vm.swappiness=1 >> /etc/sysctl.conf
      echo vm.min_free_kbytes=67584 >> /etc/sysctl.conf
      echo vm.drop_caches=1 >> /etc/sysctl.conf
      sysctl -p

      # Attaching the disks for Swap and Docker. Get the ID for these disks      
      SWAP=/dev/$(lsblk|grep nvme | grep -v nvme0n1 |sort -k 4 | awk '{print $1}'| awk '(NR==1)')
      DOCKER=/dev/$(lsblk|grep nvme | grep -v nvme0n1 |sort -k 4 | awk '{print $1}'| awk '(NR==2)')
      
      # swap
      # if SWAP exists
      # we format if no format
      if [ -b $SWAP ]; then
      	blkid $SWAP
      	if [ $? -ne 0 ]; then
      		mkswap $SWAP
      	fi
      fi
      
      # if SWAP not in fstab
      # we add it
      grep "swap" /etc/fstab
      if [ $? -ne 0 ]; then
        SWAP_UUID=`blkid $SWAP| awk '{print $2}'`
      	echo "$SWAP_UUID swap swap defaults 0 0" | tee -a /etc/fstab
      	swapon -a
      fi
      
      # docker
      # if DOCKER exists
      # we format if no format
      if [ -b $DOCKER ]; then
      	blkid $DOCKER
      	if [ $? -ne 0 ]; then
      		mkfs.xfs $DOCKER
      	fi
      fi
      
      # if DOCKER not in fstab
      # we add it
      grep "/var/lib/docker" /etc/fstab
      if [ $? -ne 0 ]; then
        DOCKER_UUID=`blkid $DOCKER| awk '{print $2}'`
      	echo "$DOCKER_UUID /var/lib/docker xfs defaults 0 0" | tee -a /etc/fstab
      	mkdir -p /var/lib/docker
      	mount -a
      fi
      
      # install Docker version 23.0.5

      for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
      
      sudo apt-get update -y
      sudo apt-get install ca-certificates curl gnupg -y
      
      # Get the keyrings and add them
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      
      echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      
      sudo apt-get update -y
      
      # list the versions
      # apt-cache madison docker-ce | awk '{ print $3 }'

      # Set the Docker version to install
      VERSION_STRING=5:23.0.6-1~ubuntu.22.04~jammy
      apt-get install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin -y     
  - path: /var/tmp/download_and_unpack_software.sh 
    permissions: '0750'
    content: |
      #!/usr/bin/env bash

      # wait until archive is available. Wait until there is internet before continue
      until ping -c1 archive.ubuntu.com &>/dev/null; do
        echo "waiting for networking to initialise"
        sleep 3 
      done 
      
      # create directory to store the certificates
      mkdir -p /opt/tfe/certs

      # Download all the software and files needed in this case the certificates
      apt-get update      
      apt-get -y install awscli
      aws s3 cp s3://${tag_prefix}-software/certificate_pem /opt/tfe/certs/cert.pem
      aws s3 cp s3://${tag_prefix}-software/issuer_pem /opt/tfe/certs/bundle.pem
      aws s3 cp s3://${tag_prefix}-software/private_key_pem /opt/tfe/certs/key.pem
  - path: /var/tmp/install_tfe.sh   
    permissions: '0750'
    content: |
      #!/usr/bin/env bash    
      

      # add the private IP address of the server to the yaml file
      AWS_TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
      LOCAL_IP=`curl -H "X-aws-ec2-metadata-token: $AWS_TOKEN" -v http://169.254.169.254/latest/meta-data/local-ipv4`
      sed -i "s/PRIVATE_IP_ADDRESS_WILL_BE_PLACED_HERE/$LOCAL_IP/g" /var/tmp/compose.yaml

      # copy the configuration file to right location
      cp /var/tmp/compose.yaml /opt/tfe/
      
      # go into the tfe application directory
      pushd /opt/tfe/
      
      # login to docker
      docker login -u="${docker_username}" -p="${docker_encryption_password}" quay.io
      
      # start the TFE application
      docker compose up --detach
  - path: /etc/tfe_initial_user.json
    permissions: '0755'
    content: |  
      {
          "username": "admin",
          "email": "${certificate_email}",
          "password": "${tfe_password}"
      }   
  - path: /etc/tfe_create_organization.json
    permissions: '0755'
    content: |  
      {
          "data": {
              "type": "organizations",
              "attributes": {
                  "name": "test",
                  "email": "${certificate_email}"
              }
          }
      }       
  - path: /var/tmp/tfe_setup.sh
    permissions: '0777'
    content: |
      #!/usr/bin/env bash
      
      # We have to wait for TFE be fully functioning before we can continue
      while true; do
          if curl -kI "https://${dns_hostname}.${dns_zonename}/admin" 2>&1 | grep -w "200\|301" ; 
          then
              echo "TFE is up and running"
              echo "Will continue in 1 minutes with the final steps"
              sleep 60
              break
          else
              echo "TFE is not available yet. Please wait..."
              sleep 60
          fi
      done

      # go into the directory of the compose.yaml file
      pushd /opt/tfe/

      # as we will run this from all servers in ASG, we will use a random sleep
      # so one server tries first
      
      # we get 2 characters from random
      WAIT=$${RANDOM:1:2}
      
      echo Info: sleeping for $WAIT
      sleep $WAIT
      
      echo "Get initial activation token"
      INITIAL_TOKEN=`docker compose exec tfe retrieve-iact`
      
      # get the admin token you can user to create the first user
      # Create the first user called admin and get the token
      curl -k --header "Content-Type: application/json" --request POST --data @/etc/tfe_initial_user.json  --url https://${dns_hostname}.${dns_zonename}/admin/initial-admin-user?token=$INITIAL_TOKEN | tee /etc/tfe_initial_user_output.json
      
      
      TOKEN=`jq -e -r .token /etc/tfe_initial_user_output.json`
      [[ $? -eq 0 && "$TOKEN" ]] || exit 1

      # create organization test
      curl -k \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/vnd.api+json" \
        --request POST \
        --data @/etc/tfe_create_organization.json \
        https://${dns_hostname}.${dns_zonename}/api/v2/organizations      
runcmd:
  - sudo bash /var/tmp/install_software.sh 
  - sudo bash /var/tmp/download_and_unpack_software.sh 
  - sudo bash /var/tmp/install_tfe.sh 
  - sudo bash /var/tmp/tfe_setup.sh
```
![](media/20220925113034.png)    
![](media/20220925113055.png)    
![](media/20220925113114.png)    
![](media/20220925113134.png)    

- The launch configuration should now be visible  
![](media/20220925113209.png)  

# Loadbalancer


- loadbalancer create a target group which we at a later point connect to the Auto Scaling Group  
 ![](media/20220520133657.png)  
 ![](media/20220520133733.png)    
- Will have no targets yet  
![](media/20220520133755.png)    

- do the same for the tfe-app port 443

- loadbalancer create a appplication load balancer which will connect to the load balancer target    
![](media/20220520133950.png)    
- following configuration  
![](media/20220520134014.png)  
![](media/20220520134040.png)    
![](media/20220520134059.png)    
![](media/20220520134138.png)    
![](media/20220520134318.png)    
![](media/20220520134341.png)    


- Auto Scaling groups. Will configure the group and connect it to auto scaling launch and the created load balancer
Make sure you switch to launch configuration   
![](media/20220925113821.png)    
![](media/20220925113853.png)    
![](media/20220925135406.png)    
![](media/20220925114017.png)   
![](media/20220925114039.png)     

- You should now see an instance being started   
![](media/20220925135505.png)      

- Alter the DNS record in route53 to point to the loadbalancer dns name    
![](media/20220520134508.png)  

- You should now be able to connect to your website   
