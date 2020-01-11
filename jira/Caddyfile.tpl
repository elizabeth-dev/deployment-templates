${domain_name} {
	proxy / http://Jira-Server:8080 {
		websocket
		transparent
	}
}
