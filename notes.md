# Bulk updates Sonicwall DHCP
## Preface
I needed to to move our centralized DHCP setup (MS DHCP) to a de-centralized setup using our cluster of Sonicwall firewalls. Having quite a bit of reservations possed a problem. Offcourse I could create them by hand on the Sonicwalls. But this is a tedious error prone job. So I decided to use the SonicOS API for that job. Never done that before... so it should be fun.  Arround all the tool suggested was cURL. Fun to fool around with. Finding out how things work. My scripting language by choise, Perl, came in handy to process CSV files created with Powershell on the MS DHCP server.
All samples are based on trial on a Sonicwall NSA5700, SonicOS 7.0.1-5080. I've noticed API changes between version.
Having to to the work on different (Linux) clients made me use GitHub for syncing between the different systems. This gave me the oppertunity to share my notes.
In this little project I learned:
- How cURL works.
- How the SonicOS API works
- How Sonicwall DHCP is configured
- Some deeper knowledge about JSON and parsing it.
- A better understanding on Git and GitHub.

## Hacking the CLI with curl
### General notes
- API endpoint can be found via the Sonicwall itself. There is a link to swagger in te legal section for the API. Takes a long time to load, but it seems all the endpoints are there. Use the browser search to find the relevant ones.
- Information can be downloaded with -X GET
- Information is in JSON format, on a 5700 it will have no formatting . Is can be cleaned up online i.e. on the site https://jsonformatter.curiousconcept.com/ to make ik human readable
- Usually that information can be written back (adapted or to a different firewall) with -X POST
- The curl option for writting back data is -d @file
- When writing data back set the header with -H "Content-Type: application/json"
- After uploading a commit is needed.

### Login

Starts a new session.

`curl -k -i --digest -u admin:password -X POST  https://10.91.0.1/api/sonicos/auth`

#### Sample result:
```
{
   "status":{
      "success":true,
      "info":[
         {
            "level":"info",
            "code":"E_OK",
            "auth_code":"API_AUTH_CAN_PREEMPT",
            "config_mode":"No",
            "read_only":"No",
            "privilege":"FULL_ADMIN",
            "curr_config_type":"NONE",
            "curr_config_ip":"0.0.0.0",
            "model":"NSa 5700",
            "is_fw_managed_by_gms_actively":true,
            "auto_ffw_upgrading":false,
            "auto_upgrade_vers":"",
            "inactivity_timer":5,
            "message":"User login in non-configuration mode."
         }
      ]
   }
}
```
The fields "config_mode" and "message" indicate that we are _not_ in config mode. We have to pre-empt the current user in order to do any configuration. This could be done by setting an option in the request, but I was not able to get that working. There is a second method: a new request to preempt the current user.

### PreEmt
PreEmts the current user. This could be done automaticly with the login, but I can't get that to work.

`curl -k -i -X POST https://10.91.0.1/api/sonicos/config-mode`
#### Sample output

## Logout

Ends the current session.

`curl -k -i -X DELETE https://10.91.0.1/api/sonicos/auth`

### Sample output
```
{
    "status": {
        "success": true,

        "info": [
            		{ 
				"level": "info", 
				"code": "E_OK", 
				"message": "Success." 
			}
        ]
    }
 }
```
### Static scopes
Get the static scopes (reservations) from the Sonicwall.

`curl -k -i -X GET https://10.91.0.1/api/sonicos/dhcp-server/ipv4/scopes/static`

#### Sample data
```
{
   "dhcp_server":{
      "ipv4":{
         "scope":{
            "static":[
               {
                  "ip":"10.41.1.1",
                  "mac":"60128BD075A4",
                  "enable":false,
                  "name":"NWT-Canon-DS0",
                  "lease_time":1440,
                  "default_gateway":"10.41.0.1",
                  "netmask":"255.255.0.0",
                  "comment":"NWT-Canon-DS0",
                  "domain_name":"",
                  "dns":{
                     "server":{
                        "inherit":true
                     }
                  },
                  "wins":{
                     "primary":"0.0.0.0",
                     "secondary":"0.0.0.0"
                  },
                  "call_manager":{
                     "primary":"",
                     "secondary":"",
                     "tertiary":""
                  },
                  "network_boot":{
                     "next_server":"0.0.0.0",
                     "boot_file":"",
                     "server_name":""
                  },
                  "generic_option":{
                     "group":"Default options"
                  },
                  "always_send_option":true
               }
            ]
         }
      }
   }
}
```

### Dynamic scopes
Get the dynamic scopes (reservations) from the Sonicwall.

`curl -k -i -X GET https://10.91.0.1/api/sonicos/dhcp-server/ipv4/scopes/dynamic`

#### Sample data
```
{
   "dhcp_server":{
      "ipv4":{
         "scope":{
            "dynamic":[
               {
                  "from":"10.44.1.1",
                  "to":"10.44.4.255",
                  "enable":true,
                  "lease_time":1440,
                  "default_gateway":"10.44.0.1",
                  "netmask":"255.255.0.0",
                  "comment":"NWT LLN Scope",
                  "allow_bootp":false,
                  "domain_name":"",
                  "dns":{
                     "server":{
                        "inherit":true
                     }
                  },
                  "wins":{
                     "primary":"0.0.0.0",
                     "secondary":"0.0.0.0"
                  },
                  "call_manager":{
                     "primary":"",
                     "secondary":"",
                     "tertiary":""
                  },
                  "network_boot":{
                     "next_server":"0.0.0.0",
                     "boot_file":"",
                     "server_name":""
                  },
                  "generic_option":{
                     "group":"Default options"
                  },
                  "always_send_option":false
               }
            ]
         }
      }
   }
}
```

### Interfaces
De interfaces:

`curl -k -i -X GET https://10.91.0.1/api/sonicos/interfaces/ipv4`

#### Sample data
Removed most for clarity.  5700 has A LOT of interfaces
```
{
   "interfaces":[
      {
         "ipv4":{
            "name":"X0",
            "ip_assignment":{
               "zone":"LAN",
               "mode":{
                  "static":{
                     "ip":"192.168.9.168",
                     "netmask":"255.255.255.0",
                     "gateway":"0.0.0.0"
                  }
               }
            },
            "comment":"Default LAN",
            "management":{
               "https":true,
               "ping":true,
               "snmp":false,
               "ssh":true,
               "fqdn_assignment":""
            },
            "user_login":{
               "http":false,
               "https":false
            },
            "https_redirect":true,
            "link_speed":{
               "auto_negotiate":true
            },
            "mac":{
               "default":true
            },
            "shutdown_port":false,
            "auto_discovery":false,
            "flow_reporting":true,
            "multicast":false,
            "cos_8021p":false,
            "exclude_route":false,
            "asymmetric_route":false,
            "management_traffic_only":false,
            "port":{
               "redundancy_aggregation":false
            },
            "routed_mode":{
               
            },
            "mtu":1500,
            "bandwidth_management":{
               "egress":{
                  
               },
               "ingress":{
                  
               }
            },
            "one_arm_mode":false,
            "one_arm_peer":"0.0.0.0"
         }
      },
      {
         "ipv4":{
            "name":"X1",
            "ip_assignment":{
               "zone":"WAN",
               "mode":{
                  "static":{
                     "ip":"217.100.5.212",
                     "netmask":"255.255.255.248",
                     "dns":{
                        "primary":"0.0.0.0",
                        "secondary":"0.0.0.0",
                        "tertiary":"0.0.0.0"
                     },
                     "gateway":"217.100.5.209"
                  }
               }
            },
            "comment":"Default WAN",
            "management":{
               "https":false,
               "ping":true,
               "snmp":false,
               "ssh":false,
               "fqdn_assignment":""
            },
            "user_login":{
               "http":false,
               "https":false
            },
            "link_speed":{
               "auto_negotiate":true
            },
            "mac":{
               "default":true
            },
            "shutdown_port":false,
            "flow_reporting":true,
            "multicast":false,
            "cos_8021p":false,
            "exclude_route":false,
            "asymmetric_route":false,
            "management_traffic_only":false,
            "port":{
               "redundancy_aggregation":false
            },
            "mtu":1500,
            "fragment_packets":true,
            "ignore_df_bit":false,
            "send_icmp_fragmentation":true,
            "bandwidth_management":{
               "egress":{
                  
               },
               "ingress":{
                  
               }
            },
            "one_arm_mode":false,
            "one_arm_peer":"0.0.0.0"
         }
      },
      {
         "ipv4":{
            "name":"X24",
            "vlan":101,
            "ip_assignment":{
               "zone":"DC-Devices",
               "mode":{
                  "static":{
                     "ip":"10.0.9.1",
                     "netmask":"255.255.255.0",
                     "gateway":"0.0.0.0"
                  }
               }
            },
            "comment":"",
            "management":{
               "https":true,
               "ping":true,
               "snmp":false,
               "ssh":false,
               "fqdn_assignment":""
            },
            "user_login":{
               "http":false,
               "https":false
            },
            "https_redirect":true,
            "mac":{
               "default":true
            },
            "flow_reporting":true,
            "multicast":false,
            "exclude_route":false,
            "asymmetric_route":false,
            "routed_mode":{
               
            },
            "mtu":1500
         }
      },
      {
         "ipv4":{
            "name":"X24",
            "vlan":102,
            "ip_assignment":{
               "zone":"DMZ",
               "mode":{
                  "static":{
                     "ip":"192.168.0.1",
                     "netmask":"255.255.255.0",
                     "gateway":"0.0.0.0"
                  }
               }
            },
            "comment":"",
            "management":{
               "https":false,
               "ping":true,
               "snmp":false,
               "ssh":false,
               "fqdn_assignment":""
            },
            "user_login":{
               "http":false,
               "https":false
            },
            "mac":{
               "default":true
            },
            "flow_reporting":true,
            "multicast":false,
            "exclude_route":false,
            "asymmetric_route":false,
            "routed_mode":{
               
            },
            "mtu":1500
         }
      }
   ]
}
```

### DHCP Options
Get the configured DHCP options:

`curl -k -i -X GET https://10.91.0.1/api/sonicos/dhcp-server/ipv4/option/objects` 

#### Sample data
```
{
	"dhcp_server": {
			"ipv4": {
					"option": {
						"object":[
								{
									"name":"DomainName",
									"number":15,
									"array":false,
									"value":[
										{"string":"atlascollege.nl"}
										]
								},
								{
									"name":"DNS Servers",
									"number":6,
									"array":true,
									"value":[
										{"ip":"10.0.9.72"},
										{"ip":"10.0.9.66"},
										{"ip":"10.0.9.56"}
										]
								},
								{
									"name":"NTP Server",
									"number":42,
									"array":false,
									"value":[
										{"ip":"10.0.9.18"}
										]
								}
							]
						}
				}
			}
}
```

vim: set tabstop=4
