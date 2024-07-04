# Web-Project
Deployment of Web Application through Terraform and Ansible. 
Step 1: 
Initialized the infrastructure with Terraform Scripts, created main.tf, variables.tf, output.tf to be carried in the execution of the automation of the web application on the EC2 instance. 
First step is to do terraform init. 
This will initialize our terraform. 
Then we will do terraform plan , this will tell us how many changes will be made. 
Then we will do terraform apply to deploy our EC2 instance on cloud and web application on EC2 instance. 
Ste 2: 
Successful configuration of web app on Ansible. 
First step is to install ansible through its documentation https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu
Then the next step is to create the inventory.yml file which will execute the hosts. 
Then we create an nginx.conf.j2 file to create our nginx configuration for the working of Nginx. 
We need to include index.html in the current project directory from where we are making ansible work. 
After creating index.html file in the current directory we need to copy it to the nginx directory to make the webapp work. 
Also we need to give necessary permissions to mime.types file in /etc/nginx/mime.types 
Need to give it chmod 644 permission on /etc/nginx/mime.types  # This file is must otherwise nginx won't work and ansible will keep giving errors. 
then we restart nginx 
Then we again execute ansible-playbook nginx_setup.yml -i inventory
Thus our project will be up and running. 
