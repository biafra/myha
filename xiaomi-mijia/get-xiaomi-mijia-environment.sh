#!/bin/bash
#
# Xiaomi Mijia Temperature & Humidity Sensor collector
#
# Based on 'mig' script
#
# https://community.home-assistant.io/t/xiaomi-mijia-bluetooth-temperature-humidity-sensor-compatibility/43568/7
#

SENSOR_BT_ADDRESS="4C:65:A8:D0:27:9D"
SENSOR_HA_NAME="sensor1"
HA_USER=********
HA_PWD=********
MQTT_ADDRESS=127.0.0.1

RET=1
until [ ${RET} -eq 0 ]; do
    data=$(/usr/bin/timeout 20 /usr/bin/gatttool -b $SENSOR_BT_ADDRESS --char-write-req --handle=0x10 -n 0100 --listen | grep "Notification handle" -m 2)
    RET=$?
    sleep 5
done

RET=1
until [ ${RET} -eq 0 ]; do
    battery=$(/usr/bin/gatttool -b $SENSOR_BT_ADDRESS --char-read --handle=0x18 | cut -c 34-35)
    RET=$?
    sleep 5
    battery=$(echo $battery | awk '{print toupper($0)}')
done

temp=$(echo $data | tail -1 | cut -c 42-54 | xxd -r -p)
humid=$(echo $data | tail -1 | cut -c 64-74 | xxd -r -p)
batt=$(echo "ibase=16; $battery"  | bc)

echo "TEMP: $temp HUMID: $humid BATT: $batt";

if [[ $batt =~ ^$ ]]
then
    batt='0.0'
fi

/usr/bin/mosquitto_pub \
        -h $MQTT_ADDRESS \
        -V mqttv311 \
        -u $HA_USER \
        -P $HA_PWD \
        -t "home/indoor/xiaomi/$SENSOR_HA_NAME" \
        -m "{ \"battery\":$batt , \"humidity\":$humid , \"temperature\":$temp}"

exit

#
# $ hciconfig
# hci0: Type: Primary  Bus: USB
#       BD Address: 00:1A:7D:DA:71:13  ACL MTU: 310:10  SCO MTU: 64:8
#       UP RUNNING
#       RX bytes:2868 acl:18 sco:0 events:172 errors:0
#       TX bytes:3503 acl:2 sco:0 commands:140 errors:0
#
# $ sudo hcitool lescan
# LE Scan ...
# 4C:65:A8:D0:27:9D (unknown)
# 4C:65:A8:D0:27:9D MJ_HT_V1
# 4C:65:A8:D0:27:9D (unknown)
#
# Or
#
# $ sudo bluetoothctl
# [NEW] Controller 00:1A:7D:DA:71:13 raspberrypi [default]
# [bluetooth]# scan on
# Discovery started
# [CHG] Controller 00:1A:7D:DA:71:13 Discovering: yes
# [NEW] Device 4C:65:A8:D0:27:9D MJ_HT_V1
#
