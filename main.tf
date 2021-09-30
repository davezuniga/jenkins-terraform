provider "aws" {
    region = "us-east-1" #Hard-coding the region
    #Static credentials
    access_key = "AKIAW2DIA2DJDXR4FE7R"
    secret_key = "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"

}

#Create vpc
resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      "Name" = "production"
    }
    
}

#Create gateway
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id 
  
}

#Create route table
resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id 

    route {
        cidr_block = "0.0.0.0/0" #Send all trafic trough gateway
        gateway_id = aws_internet_gateway.gw.id 
    }

    route {
        ipv6_cidr_block = "::/0" #Send all trafic trough gateway
        gateway_id = aws_internet_gateway.gw.id 
    }

    tags = {
      "Name" = "Prod"
    }
  
}

#Create a subnet
resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
      "NameProd-subnet" = "value"
    }
  
}


#Associate the subnet with the route table
resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.prod-route-table.id
  
}

#Create a security group
resource "aws_security_group" "allow_web" {
    name = "allow_web_trafic"
    description = "Allow web traffic trafic"
    vpc_id = aws_vpc.prod-vpc.id

    ingress  {
      description = "HTTPS"
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
    } 

    ingress {
      description = "HTTP"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
    } 

    ingress  {
      description = "ssh"
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
    } 

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

    }

    tags = {
            Name = "allow_web"
        }
  
}

#Create network interface
resource "aws_network_interface" "web-server-nic" {
    subnet_id = aws_subnet.subnet-1.id
    private_ips = [ "10.0.1.50" ]
    security_groups = [ aws_security_group.allow_web.id]
  
}

#Create a elastic (public) IP
#This depends on the gateway creation
resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.web-server-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [
      aws_internet_gateway.gw
    ]
  
} 

#Create the server
resource "aws_instance" "web-server-instance" {
    ami = "ami-09e67e426f25ce0d7"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "test"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
        #!/bin/bash
        sudo apt update -y
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo bash -c 'echo Terraform configuration completed > /var/www/html/index.html'
        EOF

    tags = {
        Name = "web-server"
    }
}


