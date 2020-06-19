#credientials loader
provider "aws" {
  region     = "ap-south-1"
  profile = "myinfo.txt"
}

#creating a security group
resource "aws_security_group" "sec" {
 # name        = "Security"
 # vpc_id = data.aws_vpc.default.id
 # description = "Allow TLS inbound traffic"
ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "vpc1"
  }
}



#vpc configuration
#data "aws_vpc" "default" {
#default = true
#}

#launching an instance
resource "aws_instance" "myin" {
 ami = "ami-005956c5f0f757d37"
 instance_type = "t2.micro"
 key_name = "tf"
 security_groups = ["${aws_security_group.sec.name}"]
connection {
  type     = "ssh"
  user     = "ec2-user"
  private_key = file("C:/Users/Manjunath D/Desktop/terraform/mytest/tf.pem")
   host = aws_instance.myin.public_ip
}

provisioner "remote-exec"{
    inline = [
      "sudo yum install httpd php git -y",
      "sudo service httpd start",
      "sudo service httpd status",
    ]

  }

 tags = {
  Name = "Webserver"
 }
}


output "myos_ip" {
  value = aws_instance.myin.public_ip
}

resource "null_resource" "null1"  {

depends_on = [
    aws_volume_attachment.ebs_attach,
  ]


 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Manjunath D/Desktop/terraform/mytest/tf.pem")
    host     = aws_instance.myin.public_ip
  }
 
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Manjuphoenix/AWS.git /var/www/html"
    ]
  }
}


resource "aws_s3_bucket" "s3bucket" {
  bucket = "iiecbucket"
  acl    = "private"
 provisioner "local-exec" {
     command = "git clone https://github.com/Manjuphoenix/AWS.git"
      }

 provisioner "local-exec" {
        when = destroy
        command = "rm -rf my-images"
       }
  tags = {
  Name = "iiecbucket"
 }
}



resource "aws_s3_bucket_public_access_block" "S3PublicAccess" {
  bucket = "${aws_s3_bucket.s3bucket.id}"
  block_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
}


resource "aws_ebs_volume" "EBS_volume" {
   availability_zone = aws_instance.myin.availability_zone
   size = 1
  tags = {
      Name = "Ebs"
   }
}



resource "aws_volume_attachment" "ebs_attach" {
   device_name = "/dev/sdh"
   volume_id   = "${aws_ebs_volume.EBS_volume.id}"
   instance_id = "${aws_instance.myin.id}"
   force_detach = true
  depends_on = [
    aws_ebs_volume.EBS_volume,
    aws_instance.myin
  ]
}



resource "aws_s3_bucket_object" "teraobject" {
  bucket = aws_s3_bucket.s3bucket.bucket
  key    = "face_swapping.jpg"
  source = "images/face_swapping.jpg"
  content_type = "image/jpg"
  acl = "public-read"
  depends_on = [
      aws_s3_bucket.s3bucket
  ]
}

locals {
  s3_origin_id = "S3-${aws_s3_bucket.s3bucket.bucket}"
      }




resource "aws_cloudfront_distribution" "mycloudfront" {
  
    origin {
    domain_name = "${aws_s3_bucket.s3bucket.bucket_regional_domain_name}"
    origin_id   = "locals.s3_origin_id"
              
    custom_origin_config {
        http_port = 80
        https_port = 80
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
         }
      }
 

 enabled = true
 is_ipv6_enabled = true


 default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "locals.s3_origin_id"

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

  viewer_certificate {
    cloudfront_default_certificate = true
  }

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Manjunath D/Desktop/terraform/mytest/tf.pem")
    host     = aws_instance.myin.public_ip
  
     }
  
  provisioner "remote-exec" {
     
      inline = [
          "sudo su << EOF",
          "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.teraobject.key}' width='500' height='500'>\" >> /var/www/html/image.html",
          "EOF"
      ]
    }  

}
