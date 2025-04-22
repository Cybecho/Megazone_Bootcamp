/*
variable "instance_type" {
  type    = string
  default = "t3.small"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "The instance type must be one of the following: t3.micro, t3.small, t3.medium."
  }
}
*/

variable "instance_type" {
  default = {
    "web" = "t3.micro",
    "db"  = "t3.medium"
  }
}
