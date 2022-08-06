#!/bin/bash

#Jan-2k22.
#Create Doman/EdgeApp/Fw name: auto-a
#propagation time estimate up to 5 minutes.

echo "
First of all, create manually one WAF setup on Real Time Manager. Get ID WAF and replace it on line #114 -> 2135." ; sleep 1

NAME=$1
[ -z $NAME ] && echo "Type the name (auto-version):" && exit 0
export NAME

TOKEN=$2
[ -z $TOKEN ] && echo "Type token: " && exit 0
export TOKEN

#for mac users =)
[ ! -f /opt/homebrew/bin/jq ] && echo "ops, jq not found."

#Create Edge Application.
curl -s --location --request POST 'https://api.azionapi.net/edge_applications' --header 'Accept: application/json; version=3' --header "Authorization: Token $TOKEN" --header 'Content-Type: application/json' --data-raw '{
    "name": "'$NAME'",
    "delivery_protocol": "http",
    "origin_type": "single_origin",
    "address": "httpbin.org",
    "origin_protocol_policy": "preserve",
    "host_header": "${host}",
    "browser_cache_settings": "honor",
    "cdn_cache_settings": "override",
    "cdn_cache_settings_maximum_ttl": 233
}' -o edge_app_created.json
cat edge_app_created.json | jq .results.id
IDEDGEAPP=$(cat edge_app_created.json | jq .results.id)
#echo ${IDEDGEAPP}

#Add Application Accceleration - GET ID.
curl -s --location --request PATCH 'https://api.azionapi.net/edge_applications/'${IDEDGEAPP} --header 'Accept: application/json; version=3' --header "Authorization: Token $TOKEN" --header 'Content-Type: application/json' --data-raw '{
        "id": 1620144023,
        "name": "'$NAME' update",
        "delivery_protocol": "http,https",
        "http_port": 80,
        "https_port": 443,
        "minimum_tls_version": "",
        "active": true,
        "application_acceleration": true,
        "caching": true,
        "device_detection": false,
        "edge_firewall": false,
        "edge_functions": false,
        "image_optimization": false,
        "l2_caching": false,
        "load_balancer": false,
        "raw_logs": false,
        "web_application_firewall": false
}' -o edge_app_updated.json

curl -s -k --location --request POST 'https://api.azionapi.net/edge_applications/'${IDEDGEAPP}'/rules_engine/response/rules' --header 'Accept: application/json; version=3' --header "Authorization: Token $TOKEN" --header 'Content-Type: application/json' --data-raw '{
      "name": "auto-rule-debug",
      "phase": "response",
      "behaviors": [
        {
          "name": "add_response_header",
          "target": "autodebug:1"
        }
      ],
      "criteria": [
        [
          {
            "variable": "${uri}",
            "operator": "starts_with",
            "conditional": "if",
            "input_value": "/"
          }
        ]
      ],
      "is_active": true
 }' -o rule_engine_response_id.json
cat rule_engine_response_id.json | jq .results.'id'
ID_RULE=$(cat rule_engine_response_id.json | jq .results| grep id | awk '{print $2}' | tr -d ',')

#-------------------DOMAIN
curl -s -XPOST 'https://api.azionapi.net/domains' --header 'Accept: application/json; version=3' --header "Authorization: Token $TOKEN" --header 'Content-Type: application/json' --data-raw '{
    "name": "'$NAME'",
    "cnames": ["'$NAME'.n1c2a3t3h4r1e.au"],
    "cname_access_only": false,
    "digital_certificate_id": null,
    "edge_application_id": "'$IDEDGEAPP'",
    "is_active": true
}' -o edge_domain_created.json


#-------------------FW
ID_DOMAIN=$(cat edge_domain_created.json | jq .results.id)
curl -q -v --location --request POST 'https://api.azionapi.net/edge_firewall' --header 'Accept: application/json; version=3' --header "Authorization: Token $TOKEN" --header 'Content-Type: application/json' --data-raw '{
    "name": "'$NAME'",
    "domains": ['$ID_DOMAIN'],
    "is_active": true,
    "edge_functions_enabled": false,
    "network_protection_enabled": true,
    "waf_enabled": true
    }' -o edge_firewall_created.json
ID_FIREWALL=$(cat edge_firewall_created.json | jq .results.id)

#-------------------Pre require is create an WAF configure. Get the ID WAF and replace it with the bellow "2135"
curl -q -v --location --request POST 'https://api.azionapi.net/edge_firewall/'${ID_FIREWALL}'/rules_engine' --header 'Accept: application/json; version=3' --header "Authorization: Token $TOKEN" --header 'Content-Type: application/json' --data-raw '{
  "name": "auto-h",
  "is_active": true,
  "behaviors": [
    {
      "name": "set_waf_ruleset_and_waf_mode",
      "argument": {
        "waf_mode": "blocking",
        "set_waf_ruleset_and_waf_mode": "2135"
      }
    }
  ],
  "criteria": [
    [
      {
        "variable": "request_uri",
        "operator": "matches",
        "conditional": "if",
        "argument": "/"
      }
    ]
  ]
}' -o firewall_rule_added.json


ls -lrt edge_app_created.json edge_app_updated.json rule_engine_response_id.json edge_domain_created.json edge_firewall_created.json firewall_rule_added.json

#Get the ID and go ahead.
DOMAINAZION=$(cat edge_domain_created.json | jq .results.domain_name | tr -d '"')
IPEDGE=$(dig +short ${DOMAINAZION} @1.1.1.1 | head -1)
export DOMAINAZION IPEDGE
echo $DOMAINAZION
echo $IPEDGE
