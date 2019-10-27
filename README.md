## DevOps use case: A Terraform module used to configure and deploy an auto-scalable Amazon ECS (Elastic Container Service) cluster, as well as registering services at run-time.

NOTE: In order to proceed this guide, prior DevOps knowledge of working with the following technologies is highly required:

* Terraform
* Hashicorp Configuration Language (HCL)
* Amazon ECS (Elastic Container Service)
* Amazon EC2 cloud infrastructure
* Amazon CloudWatch
* JSON

NOTE: Before you start reading this guide, it is highly recommended to get familiar with production rule-based auto-scaling solutions. You need to know the following three Scaling Adjustment Types:
ChangeInCapacity
ExactCapacity
PercentChangeInCapacity
<br><br>
To this end, this manuscript published in the Oxford University Press written by me is helpful:<br>
`“Dynamic Multi-level Auto-scaling Rules for Containerized Applications”, The Computer Journal, Oxford University Press.`<br>
https://doi.org/10.1093/comjnl/bxy043
<br><br>
Amazon Elastic Container Service (Amazon ECS) is a highly scalable, high-performance Docker container orchestration service, by which we can run and scale containerised applications on AWS. 
Amazon ECS eliminates the need for you to install and operate your own container orchestration software, manage and scale a cluster of VMs, or schedule containers on those VMs.
With API calls, we can scale up or scale down Dockerised services, query the complete state of the application, and access many features such as security groups, load balancers, Amazon CloudWatch Events, and so on.
<br><br>
This repository is about how to setup a Terraform module used to provision a scalable ECS cluster on AWS servers. 
In other words, how to create a Terraform module to deploy an auto-scalable Amazon ECS cluster and register web services associated with it.
Therefore, we are going to prepare Terraform recipes in order to manage AWS VPC (Virtual Private Cloud), create subnet, set up Internet gateway, deploy load balancer, run scalable container-based application and so on.
<br><br>
![Image](https://github.com/salmant/DevOps-Terraform-ECS-Scalable-Cluster/blob/master/general-view.png)
<br><br>
Before you begin, make sure you have your own Terraform configuration management tool. 
Moreover, we assume that you already have your credentials including the `--aws-access-key-id` and `--aws-secret-key` parameters of a user with IAM permissions for EC2 and ECS tasks.
<br><br>
It should be noted that Amazon uses public–key cryptography to encrypt and decrypt login information. This uses a public key to encrypt, and then the recipient uses the private key to decrypt. The public and private keys are known as a key pair.
Threfore, we suppose that you have an existing key pair because to login to your instances, you need this key pair when you connect to the instances.
Also you need to make sure that there is a value for the `region` and `availability_zone`.
<br><br>
Your `--aws-access-key-id`, `--aws-secret-key`, `ssh_key_name`, `region` and `availability_zone` should be specified in this file: [variables.tf](https://github.com/salmant/DevOps-Terraform-ECS-Scalable-Cluster/blob/master/variables.tf) <br>

## Variables
Input variables serve as parameters for the Terraform module, allowing aspects of the module to be customised without altering the source code written in the module. This allows the module to be easily shared between different configurations.
Other variables specified in `variables.tf` are as follows:

* `instance_type`: The type of instance to start. The default value is `t2.micro`.
* `ecs_cluster_name`: Name of the ECS cluster. The default value is `main`.
* `cooldown_policy`: Seconds between auto scaling actions. The default value is `60`.
* `scaling_adjustment_up_policy`: How many instances to scale up if a scaling up alarm is triggered`. The default value is `1`.
* `scaling_adjustment_down_policy`: How many instances to scale down if a scaling down alarm is triggered`. The default value is `-1`.
* `metric_name_cloudwatch`: Scaling action is based on which monitoring metric. The default value is `CPUUtilization`.
* `adjustment_type_policy`: Type for step scaling and simple scaling. It can be ChangeInCapacity, ExactCapacity or PercentChangeInCapacity. The default is `ChangeInCapacity`.
* `alarm_up_scaling_threshold_cloudwatch`: Threshold to trigger an up scaling alarm. The default value is `80`.
* `alarm_down_scaling_threshold_cloudwatch`: Threshold to trigger a down scaling alarm. The default value is `40`.
* `alarm_period_cloudwatch`: The time period in seconds to check the monitoring metric statistics. The default value is `60`.
* `alarm_evaluation_periods_cloudwatch`: The number of periods over which monitoring data is investigated if specified thresholds are violated. The default value is `2`.
* `autoscale_min_size`: Minimum size of the autoscale group that is the minimum number of EC2. The default value is `1`.
* `autoscale_max_size`: Maximum size of the autoscale group that is the maximum number of EC2. The default value is `2`.
* `autoscale_desired_size`: `Desired size of the autoscale group that is the desired number of EC2. The default value is `1`.

## Some hints
This module provides an auto-scaling method which horizontally adds container instance if an aggregated metric (e.g. average `CPUUtilization` of the cluster) reaches the predefined UP% threshold called `alarm_up_scaling_threshold_cloudwatch`, and removes container instance when it falls below the predetermined DOWN% threshold called `alarm_down_scaling_threshold_cloudwatch` for a default number of successive intervals, e.g. `alarm_evaluation_periods_cloudwatch` is set to 2 intervals. 
<br><br>
Assigning a feasible value for the `instance_type` is important to avoid both under-provisioning and over-provisioning. It should be chosen based on requirements of the use case. 
Here, I selected the small general-purpose instance type named `t2.micro` which has somehow minimal CPU and memory capacity.
<br><br>
In the code, one VPC named `subnet_1` is created. 
VPC allows us to provision a private, isolated section of the AWS cloud where we are able to launch our required EC2 instance in a virtual network. 
If you would like to have more than one VPC, the variable called availability_zone should have more than two values: 

```
variable "availability_zone" {
  description = "The zones where the AWS resources will be launched"
  type        = "list"
  default     = "eu-west-2a", "eu-west-2b"
}
```

In this case, the code will be as follows:

```
/*
 * Provide details about the VPC subnet_1
 */
resource "aws_subnet" "subnet_1" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.availability_zone[0]}"
}

/*
 * Provide details about the VPC subnet_2
 */
resource "aws_subnet" "subnet_2" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.availability_zone[1]}"
}
```
<br><br>
The adjustment type for step scaling in aws_autoscaling_policy is defined as `ChangeInCapacity`. 
It means that the auto-scaler increases or decreases the current capacity of the group by the specified number of instances. 
A positive value for `scaling_adjustment_up_policy` increases the capacity and a negative value for `scaling_adjustment_down_policy` decreases the capacity. 
For example, if the current capacity of the group is 3 instances and the adjustment is 1, then when this policy is performed, there is 1 instance added to the group for a total of 4 instances.
<br><br>
In the code, the inbound traffic from the world is enabled on ports 22 (`ssh`) and 80 (`http`) for instances in our default security group. 
This mean that we can have a direct access to make connections via for example SSH on the server just because of troubleshooting. Afterwards, it is possible to eliminate existing rules or add new rules to the security group. 
You can change it according to your needs to be addressed for your own use case.
For a real-world production environment, in order to access instances on a private subnet via `ssh`, a bastion host is required to be at first connected to the instances through it. 
In security group `ecs_sg`, the third rule restricts all inbound traffic to only allow traffic from the load balancer.
<br><br>
When you apply the Terraform module, it takes some time to provision the resoirces, create subnet, set up Internet gateway, deploy load balancer and run containers. 
If the deployment step is finished, there will be one machine initialised in the cluster at first step. 
In the Amazon ECS console, choose section named `Clusters` on the navigation panel. The name of cluster should be `main`. 
Now, you see the value of 1 as the number of `registered container instances` at first step. 
It is also possible to find the public IP of machines in the cluster via different ways such as the Amazon EC2 console. 
When this instance is in service, copy the public IP address and and paste it into the address field of an Internet-connected web browser such as http://X.Y.Z.W:80/index.html. If the instance is healthy, you see the default page of the server.


You can also ssh the instance and check the currently running Docker containers.

```
[root@ip-10-0-1-50 ~]# docker ps
CONTAINER ID        IMAGE                            COMMAND                  CREATED              STATUS              PORTS                NAMES
d354b2e371f2        nginx                            "nginx -g 'daemon of…"   About a minute ago   Up About a minute   0.0.0.0:80->80/tcp   ecs-web-service-3-web-service-bad62db99fa35889b401
0e597f472751        amazon/amazon-ecs-agent:latest   "/agent"                 2 minutes ago        Up 2 minutes                             ecs-agent
```

For the troubleshooting purpose, do not forget to check the log files for the container agent and Docker via running the following commands:
sudo cat /var/log/ecs/ecs-agent.log.YYYY-MM-DD-**
sudo cat /var/log/docker
<br><br>
In order to verify the load balancer, open the Amazon EC2 console and choose section named `Load Balancers` on the navigation panel. The name of load balancer should be `web-service-elb`.
After at least one of instances is in service, you can test the load balancer. Copy the string from DNS name (such as `web-service-elb-389921337.eu-west-2.elb.amazonaws.com`) and paste it into the address field of an Internet-connected web browser. 
If the load balancer is working, you see the default page of the server. For example: http://web-service-elb-389921337.eu-west-2.elb.amazonaws.com:80/index.html
<br>
