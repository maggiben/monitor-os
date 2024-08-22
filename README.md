## Create service in main host
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

## Create service on the watering host
`sudo vi /etc/systemd/system/indoor-watering-status.service`
Add this code
```sh
[Unit]
Description=Indoor Watering Status Service
After=network.target

[Service]
Type=simple
User=bmaggi
WorkingDirectory=/monitor
ExecStart=/monitor/base.watering.sh
Restart=always

[Install]
WantedBy=multi-user.target
```