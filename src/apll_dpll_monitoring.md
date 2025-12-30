# APLL-DPLL Monitoring
```
#!bin/sh
while true;
    do
        (date; echo "#### Running a new iteration ####") >> /var/tmp/sensors_log.txt
        ( date ; echo "command: sensors" ; sensors ) >> /var/tmp/sensors_log.txt
        ( date ; echo "command: show chassis environment no-forwarding | no-more" ; cli -c 'show chassis environment no-forwarding | no-more' ) >> /var/tmp/sensors_log.txt
        ( date ; echo "command: jbcmcmd.py -show temp" ; jbcmcmd.py "show temp" ) >> /var/tmp/sensors_log.txt
        ( date ; echo "command: APLL:" ; i2cset -y 1 9 0xfd 0x0;i2cget -y 1 9 0x48 i 1 ) >> /var/tmp/sensors_log.txt
        ( date ; echo "command: DPLL:" ; i2cset -y 1 0x9 0xfd 0x5;i2cget -y 1 0x9 0x72 ) >> /var/tmp/sensors_log.txt
        ( date ; echo "command:show chassis power detail:" ; cli -c 'show chassis power detail | no-more' )  >> /var/tmp/sensors_log.txt
 
        sleep 5
    done
```
