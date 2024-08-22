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
`sudo vi /etc/systemd/system/monitor-watering.service`
Add this code
```sh
[Unit]
Description=Watering monitoring service
After=network.target

[Service]
Type=simple
User=root
Group=root
Environment="PATH=/home/bmaggi/.platformio/penv/bin:/monitor/pyenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
WorkingDirectory=/monitor
ExecStart=/monitor/base.watering.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

### Status
> `sudo systemctl status monitor-watering`
### Enable on reboot
> `sudo systemctl enable monitor-watering`
### Restart on reboot
> `sudo systemctl restart monitor-watering`
### Start on reboot
> `sudo systemctl start monitor-watering`
