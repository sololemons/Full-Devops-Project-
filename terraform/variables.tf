variable "region" {
     default = "eu-west-1" 
     }
variable "project_name" {
     default = "kijanikiosk" 
     }
variable "environment" { 
    default = "staging" 
    }
variable "user_id" { 
    default = "solomon" 
    } 

variable "vpc_cidr" { 
    default = "10.0.0.0/16"
     }
variable "azs" { 
    default = ["eu-west-1a", "eu-west-1b"] 
    }
variable "public_subnets" { 
    default = ["10.0.1.0/24", "10.0.2.0/24"] 
    }

variable "cluster_name" {
     default = "kijani-staging-cluster" 
     }
variable "kubernetes_version" { 
    default = "1.30"
     }

variable "node_instance_types" { 
    default = ["t3.micro"] 
    }
variable "node_min_size" { 
    default = 2
    }
variable "node_max_size" {
     default = 3
     }
variable "node_desired_size" { 
    default = 2
    }

variable "namespace" {
     default = "kijani-staging" 
     }
variable "service_account_name" {
     default = "kk-payments-sa" 
     }