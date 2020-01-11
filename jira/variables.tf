variable "docker_ca" {
	type = string
}

variable "docker_cert" {
	type = string
}

variable "docker_key" {
	type = string
}

variable "mysql_root_password" {
	type = string
}

variable "mysql_database" {
	type = string
	default = "jiradb"
}

variable "mysql_user" {
	type = string
	default = "jira"
}

variable "mysql_password" {
	type = string
}

variable "domain_name" {
	type = string
}

variable "jira_server_host" {
    type = string
}

variable "jira_data_host" {
    type = string
}
