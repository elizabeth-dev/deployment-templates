provider "docker" {
	alias = "data"
	host = "tcp://${var.jira_data_host}:2376/"
	ca_material = var.docker_ca
	cert_material = var.docker_cert
	key_material = var.docker_key
}

provider "docker" {
	alias = "server"
	host = "tcp://${var.jira_server_host}:2376/"
	ca_material = var.docker_ca
	cert_material = var.docker_cert
	key_material = var.docker_key
}

# Networking

resource "docker_network" "jira_network" {
	provider = docker.server

	name = "jira-network"
	driver = "overlay"

	attachable = true
	options = {
		"com.docker.network.driver.overlay.vxlanid_list" = "4098"
		encrypted = ""
	}

	/*lifecycle {
		ignore_changes = [
			options["com.docker.network.driver.overlay.vxlanid_list"]
		]
	}*/
}

# DB

resource "docker_image" "mysql" {
	provider = docker.data
	name = "mysql:5.7"
}

resource "docker_volume" "jira_database_volume" {
	provider = docker.data
	name = "DB-Volume"

	labels = {
		component = "database"
		sensitive = true
		project = "jira"
		resource = "volume"
	}
}

resource "docker_container" "jira_database" {
	provider = docker.data
	name = "Jira-DB"
	image = docker_image.mysql.latest

	labels = {
		component = "database"
		sensitive = false
		project = "jira"
		resource = "container"
	}

	command = ["--character-set-server=utf8mb4", "--collation-server=utf8mb4_bin", "--default-storage-engine=INNODB", "--innodb-default-row-format=DYNAMIC", "--innodb-large-prefix=ON", "--innodb-file-format=Barracuda", "--innodb-log-file-size=2G"]

	env = [
		"MYSQL_ROOT_PASSWORD=${var.mysql_root_password}",
		"MYSQL_DATABASE=${var.mysql_database}",
		"MYSQL_USER=${var.mysql_user}",
		"MYSQL_PASSWORD=${var.mysql_password}"
	]

	networks_advanced {
		name = docker_network.jira_network.name
	}

	restart = "always"

	volumes {
		volume_name = docker_volume.jira_database_volume.name
		container_path = "/var/lib/mysql"
	}
}

# Server

resource "docker_image" "jira" {
	provider = docker.server
	name = "atlassian/jira-software"
}

resource "docker_volume" "jira_server_volume" {
	provider = docker.server
	name = "Jira-Volume"

	labels = {
		component = "server"
		sensitive = true
		project = "jira"
		resource = "volume"
	}
}

resource "docker_container" "jira_server" {
	provider = docker.server
	name = "Jira-Server"
	image = docker_image.jira.latest

	labels = {
		component = "server"
		sensitive = false
		project = "jira"
		resource = "container"
	}

	env = [
		"VM_MAXIMUM_MEMORY=1400m",
		"ATL_PROXY_NAME=${var.domain_name}",
		"ATL_PROXY_PORT=443",
		"ATL_TOMCAT_PORT=8080",
		"ATL_TOMCAT_SCHEME=https",
		"ATL_TOMCAT_SECURE=true",
		"ATL_JDBC_URL=jdbc:mysql://${docker_container.jira_database.name}/${var.mysql_database}?useSSL=false",
		"ATL_JDBC_USER=${var.mysql_user}",
		"ATL_JDBC_PASSWORD=${var.mysql_password}",
		"ATL_DB_SCHEMA_NAME=${var.mysql_database}",
		"ATL_DB_DRIVER=com.mysql.jdbc.Driver",
		"ATL_DB_TYPE=mysql"
	]

	networks_advanced {
		name = docker_network.jira_network.name
	}

	restart = "always"

	volumes {
		volume_name = docker_volume.jira_server_volume.name
		container_path = "/var/atlassian/application-data/jira"
	}

	upload {
		content_base64 = filebase64("mysql-connector-java-5.1.48.jar")
		file = "/opt/atlassian/jira/lib/mysql-connector-java-5.1.48.jar"
	}
}

# Ingress

resource "docker_image" "caddy" {
	provider = docker.server
	name = "abiosoft/caddy"
}

resource "docker_container" "jira_ingress" {
	provider = docker.server
	name = "Jira-Ingress"
	image = docker_image.caddy.latest

	labels = {
		component = "ingress"
		sensitive = false
		project = "jira"
		resource = "container"
	}

	ports {
		internal = 80
		external = 80
	}
	ports {
		internal = 443
		external = 443
	}
	ports {
		internal = 443
		external = 443
		protocol = "udp"
	}

	command = ["--conf=/etc/Caddyfile", "--log=stdout", "--quic", "--agree", "--email=gatetes@alba.sh"]

	upload {
		content = <<EOT
${var.domain_name} {
	proxy / http://${docker_container.jira_server.name}:8080 {
		websocket
		transparent
	}
}
		EOT
		file = "/etc/Caddyfile"
	}

	networks_advanced {
		name = docker_network.jira_network.name
	}

	restart = "always"
}
