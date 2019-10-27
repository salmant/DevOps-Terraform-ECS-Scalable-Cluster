/*
 * The AWS resource provider needs to be configured with the proper credentials before it can be used
 */
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
}
