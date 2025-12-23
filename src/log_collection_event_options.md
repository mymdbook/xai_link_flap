# Event-Options Config
- Event option configuration for log collection script during flap

```text
root@xai-qfx5240-01# show event-options 
policy server_links {
    events snmp_trap_link_down;
    within 1 {
        trigger on 1;
    }
    attributes-match {
        event.snmp_trap_link_down matches "^SNMP_TRAP_LINK_DOWN$";
    }
    then {
        execute-commands {
            commands {
                "request routing-engine execute command \"sh /var/tmp/cs_event-based-script.sh >> /var/log/interface_flap.txt\"";
            }
            output-filename event_option_execution.txt;
            destination destination;
            output-format text;
        }
        raise-trap;
    }
}
destinations {
    destination {
        archive-sites {
            /var/log/;
        }
    }
}
```
