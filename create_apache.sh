#! /bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
sudo systemctl enable httpd --now
sudo yum install git -y
sudo yum install rsync -y
cd /home/ec2-user/tmp/; sudo git clone https://github.com/alefinir/static-site.git
sudo rsync -av /home/ec2-user/tmp/static-site/ /var/www/html