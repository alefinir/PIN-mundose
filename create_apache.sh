#! /bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
sudo systemctl enable httpd --now
sudo yum install git
#sudo echo "<h1>Hello World From MUNDOS-E</h1>" > /var/www/html/index.
cd /var/www/html/; git clone https://github.com/alefinir/static-site.git