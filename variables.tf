variable "aws_access_key" {
  description = "The AWS access key."
  default     = "XXXX"
}

variable "aws_secret_key" {
  description = "The AWS secret key."
  default     = "YYYY"
}

variable "ssh_key_name" {
  description = "Name of SSH key pair to be used as default user key"
  default     = "ZZZZ"
}

variable "region" {
  description = "AWS region to create resources in"
  default     = "eu-west-2"
}

variable "availability_zone" {
  description = "Availability zone"
  default     = "eu-west-2a"
}

variable "instance_type" {
  description = "The type of instance to start"
  default     = "t2.micro"
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  default     = "main"
}

variable "cooldown_policy" {
  description = "Seconds between auto scaling actions"
  default     = "60"
}

variable "scaling_adjustment_up_policy" {
  description = "How many instances to scale up if a scaling up alarm is triggered"
  default     = "1"
}

variable "scaling_adjustment_down_policy" {
  description = "How many instances to scale down if a scaling down alarm is triggered"
  default     = "-1"
}

variable "metric_name_cloudwatch" {
  description = "Scaling action is based on which monitoring metric"
  default     = "CPUUtilization"
}

variable "adjustment_type_policy" {
  description = "Type for step scaling and simple scaling. It can be ChangeInCapacity, ExactCapacity or PercentChangeInCapacity."
  default     = "ChangeInCapacity"
}

variable "alarm_up_scaling_threshold_cloudwatch" {
  description = "Threshold to trigger an up scaling alarm"
  default     = "80"
}

variable "alarm_down_scaling_threshold_cloudwatch" {
  description = "Threshold to trigger a down scaling alarm"
  default     = "40"
}

variable "alarm_period_cloudwatch" {
  description = "The time period in seconds to check the monitoring metric statistics"
  default     = "60"
}

variable "alarm_evaluation_periods_cloudwatch" {
  description = "The number of periods over which monitoring data is investigated if specified thresholds are violated"
  default     = "2"

}

variable "autoscale_min_size" {
  description = "Minimum size of the autoscale group that is the minimum number of EC2"
  default     = "1"
}

variable "autoscale_max_size" {
  description = "Maximum size of the autoscale group that is the maximum number of EC2"
  default     = "3"
}

variable "autoscale_desired_size" {
  description = "Desired size of the autoscale group that is the desired number of EC2"
  default     = "1"
}
