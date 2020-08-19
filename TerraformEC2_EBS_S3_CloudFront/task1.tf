variable "enter_ur_profile_name" {
     type = string
  //   default = "Dev"
}

#CREATING AWS PROVIDER WITH REQUIRED PROFILE NAME
provider "aws" {                                 
  region = "ap-south-1"
  profile = var.enter_ur_profile_name
}

#CREATING KEY PAIR
resource "tls_private_key" "keypairos" {
  algorithm   = "RSA"
  rsa_bits = 2048
}

resource "local_file" "keypairos2" {
    content     = tls_private_key.keypairos.private_key_pem
    filename = "os.pem"  
    file_permission = 0400	
}


resource "aws_key_pair" "deployer" {
  key_name   = "os"
  public_key = tls_private_key.keypairos.public_key_openssh
}

#SETTING DEFAULT VPC
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }  

}


#SETTING SECURITY GROUP

resource "aws_security_group" "security" {
  vpc_id = aws_default_vpc.default.id
  name        = "websecurity"
ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "websecuritygroup"
  }
}

#CREATING AN EC2 INSTANCE WITH ALL ABOVE ABBREVIATIONS USED

resource "aws_instance" "myoperatingsys" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name
  security_groups = [ "websecurity" ]
  
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.keypairos.private_key_pem
    host     = aws_instance.myoperatingsys.public_ip
  }


   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y ",
      "sudo systemctl restart httpd",
       "sudo systemctl enable httpd",
        
    ]
  }

 tags = {
       Name = "MyOS1"
      }

}

#CREATING AN EBS VOLUME

resource "aws_ebs_volume" "volume1" {
  availability_zone = aws_instance.myoperatingsys.availability_zone
  size              = 1
  tags = {
     Name = "Volume1"
       }
}

#ATTACHING IT TO EC2 INSTANCES

resource "aws_volume_attachment" "ebsattach" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.volume1.id
  instance_id = aws_instance.myoperatingsys.id
}

#COPY THE CONTENT OF GITHUB RESPIRATORY TO /var/www/html/

resource "null_resource" "nullremote3" {
  
   depends_on = [
    aws_volume_attachment.ebsattach,
  ]

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.keypairos.private_key_pem
    host     = aws_instance.myoperatingsys.public_ip
  }


provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh ",
      "sudo mount /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/DevendraJohari24/multicloud.git   /var/www/html",
    ]
  }
}


#CREATING AN S3 BUCKET 

resource "aws_s3_bucket" "s3_bucketos" {
	bucket = "os-bucket-dev0608"  
  	acl    = "public-read"

         connection {
         type     = "ssh"
         user     = "ec2-user"
          private_key = tls_private_key.keypairos.private_key_pem
          host     = aws_instance.myoperatingsys.public_ip
         }
	
  	tags = {
   	Name        = "My-S3-bucket"
    	Environment = "Production"
  	}
	versioning {
	enabled= true
	}
 
}
 
#CREATING A CLOUD FRONT

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.s3_bucketos.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    
    custom_origin_config {
            		http_port = 80
            		https_port = 80
            		origin_protocol_policy = "match-viewer"
            	origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        	}
   
  }

  enabled             = true



  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
 

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

#OUTPUT IP SHOWN IN COMMAND PROMPT
output "myos_ip" {
    value = aws_instance.myoperatingsys.public_ip
}

#SAVE IP TO LOCAL FILE 
resource "null_resource" "nulllocal1" {
     provisioner "local-exec" {
             command = "echo ${aws_instance.myoperatingsys.public_ip} >publicip.txt"
          }
}

#OPENING CHROME AND SEARCH IP

resource "null_resource" "nulllocal0608"  {

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.myoperatingsys.public_ip}"
  	}
}



