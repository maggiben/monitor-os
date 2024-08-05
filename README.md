## Create service
`sudo vi /etc/systemd/system/indoor-sensor-status.service`
Add this code
```sh
[Unit]
Description=Indoor Sensor Status Service
After=network.target

[Service]
Type=simple
User=bmaggi
WorkingDirectory=/monitor
ExecStart=/monitor/base.sh
Restart=always

[Install]
WantedBy=multi-user.target
```