/*
 * Create a virtual private cloud (VPC) resource
 */
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
}

/*
 * Create Public Route Table
 */
resource "aws_route_table" "public_rt" {
    vpc_id = "${aws_vpc.main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.main.id}"
    }
}

/*
 * Provide a resource to create an association between the route table and subnet_1 
 */
resource "aws_route_table_association" "public_rt-main" {
    subnet_id = "${aws_subnet.subnet_1.id}"
    route_table_id = "${aws_route_table.public_rt.id}"
}

/*
 * Create the VPC subnet called subnet_1
 */
resource "aws_subnet" "subnet_1" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.1.0/24"
    availability_zone = "${var.availability_zone}"
}

/*
 * Create the Internet Gateway
 */
resource "aws_internet_gateway" "main" {
    vpc_id = "${aws_vpc.main.id}"
}

/*
 * Create a Security Group for Load Balancer
 */
resource "aws_security_group" "lb_sg" {
    name = "lb_sg"
    vpc_id = "${aws_vpc.main.id}"

    # http
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # who can access it? The world!
    }

    # Without limitation
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

/*
 * Create a Security Group for Machines in the ECS Cluster
 */
resource "aws_security_group" "ecs_sg" {
    name = "ecs_sg"
    vpc_id = "${aws_vpc.main.id}"

    # http
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # who can access it? The world!
    }
	# ssh
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # who can access it? The world!
    }

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        security_groups = ["${aws_security_group.lb_sg.id}"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

/*
 * Create an ECS Cluster
 */
resource "aws_ecs_cluster" "main" {
    name = "${var.ecs_cluster_name}"
}

/*
 * Create Autoscaling Group
 */
resource "aws_autoscaling_group" "asg" {
    availability_zones = ["${var.availability_zone}"]
    name = "${var.ecs_cluster_name}"
    min_size = "${var.autoscale_min_size}"
    max_size = "${var.autoscale_max_size}"
    desired_capacity = "${var.autoscale_desired_size}"
    health_check_type = "EC2"
    launch_configuration = "${aws_launch_configuration.ecs.name}"
    vpc_zone_identifier = ["${aws_subnet.subnet_1.id}"]
}

/*
 * Create Autoscaling Policy for Scaling Up
 */
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "${var.ecs_cluster_name}-scale_up_policy"
  cooldown               = "${var.cooldown_policy}"
  scaling_adjustment     = "${var.scaling_adjustment_up_policy}"
  adjustment_type        = "${var.adjustment_type_policy}"
  autoscaling_group_name = "${aws_autoscaling_group.asg.name}"
}

/*
 * Create Autoscaling Policy for Scaling Down
 */
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "${var.ecs_cluster_name}-scale_down_policy"
  cooldown               = "${var.cooldown_policy}"
  scaling_adjustment     = "${var.scaling_adjustment_down_policy}"
  adjustment_type        = "${var.adjustment_type_policy}"
  autoscaling_group_name = "${aws_autoscaling_group.asg.name}"
}

/*
 * Create a CloudWatch Metric Alarm for Scaling Up
 */
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "${var.ecs_cluster_name}-scale_up_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  period              = "${var.alarm_period_cloudwatch}"
  evaluation_periods  = "${var.alarm_evaluation_periods_cloudwatch}"
  metric_name         = "${var.metric_name_cloudwatch}"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  threshold           = "${var.alarm_up_scaling_threshold_cloudwatch}"
  alarm_actions       = ["${aws_autoscaling_policy.scale_up_policy.arn}"]
}

/*
 * Create a CloudWatch Metric Alarm for Scaling Down
 */
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "${var.ecs_cluster_name}-scale_down_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  period              = "${var.alarm_period_cloudwatch}"
  evaluation_periods  = "${var.alarm_evaluation_periods_cloudwatch}"
  metric_name         = "${var.metric_name_cloudwatch}"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  threshold           = "${var.alarm_down_scaling_threshold_cloudwatch}"
  alarm_actions       = ["${aws_autoscaling_policy.scale_down_policy.arn}"]
} 

/*
 * Get the ID of the most recent, registered, ECS-optimized AMI for use
 */
data "aws_ami" "latest_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name      = "name"
    values    = ["amzn-ami-*-amazon-ecs-optimized"]
  }
}

/*
 * Create a new Launch Configuration used for Autoscaling Group
 */
resource "aws_launch_configuration" "ecs" {
    name = "${var.ecs_cluster_name}"
    image_id = "${data.aws_ami.latest_ami.id}"
    instance_type = "${var.instance_type}"
    security_groups = ["${aws_security_group.ecs_sg.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.ecs.name}"
    key_name = "${var.ssh_key_name}"
    associate_public_ip_address = true
    user_data = "#!/bin/bash\necho ECS_CLUSTER='${var.ecs_cluster_name}' > /etc/ecs/ecs.config"
}

/*
 * Create an IAM Role for Machines in the ECS Cluster
 */
resource "aws_iam_role" "ecs_instance_role" {
    name = "ecs_instance_role"
    assume_role_policy = "${file("ecs-ec2-role.json")}"
}

/*
 * Create an IAM Role Policy for Machines in the ECS Cluster
 */
resource "aws_iam_role_policy" "ecs_instance_role_policy" {
    name = "ecs_instance_role_policy"
    policy = "${file("ecs-instance-role-policy.json")}"
    role = "${aws_iam_role.ecs_instance_role.id}"
}

/*
 * Create an IAM Role for Services
 */
resource "aws_iam_role" "ecs_service_role" {
    name = "ecs_service_role"
    assume_role_policy = "${file("ecs-ec2-role.json")}"
}

/*
 * Create an IAM Role Policy for Services
 */
resource "aws_iam_role_policy" "ecs_service_role_policy" {
    name = "ecs_service_role_policy"
    policy = "${file("ecs-service-role-policy.json")}"
    role = "${aws_iam_role.ecs_service_role.id}"
}

/*
 * Create an IAM Instance Profile
 */
resource "aws_iam_instance_profile" "ecs" {
    name = "ecs-instance-profile"
    path = "/"
    role = "${aws_iam_role.ecs_instance_role.name}"
}
