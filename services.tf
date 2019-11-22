/*
 * Create an Elastic Load Balancer
 */
resource "aws_elb" "web-service" {
    name = "web-service-elb"
    security_groups = ["${aws_security_group.lb_sg.id}"]
    subnets = ["${aws_subnet.subnet_1.id}"]

    listener {
        lb_protocol = "http"
        lb_port = 80

        instance_protocol = "http"
        instance_port = 80
    }

    health_check {
        healthy_threshold = 3
        unhealthy_threshold = 2
        timeout = 3
        target = "HTTP:80/index.html"
        interval = 5
    }

    cross_zone_load_balancing = true
}

/*
 * Create an ECS task definition to be used in "aws_ecs_service"
 */
resource "aws_ecs_task_definition" "web-service" {
    family = "web-service"
    container_definitions = "${file("web-service.json")}"
}

/*
 * Create an ECS service - a task that is expected to run until an error occurs or a user terminates it
 */
resource "aws_ecs_service" "web-service" {
    name = "web-service"
    cluster = "${aws_ecs_cluster.main.id}"
    task_definition = "${aws_ecs_task_definition.web-service.arn}"
    iam_role = "${aws_iam_role.ecs_service_role.arn}"
    # (Optional) The number of instances of the task definition to place and keep running. Create service with 2 instances to start.
    desired_count = 2
    depends_on = ["aws_iam_role_policy.ecs_service_role_policy"]

    load_balancer {
        elb_name = "${aws_elb.web-service.id}"
        container_name = "web-service"
        container_port = 80
    }
}

