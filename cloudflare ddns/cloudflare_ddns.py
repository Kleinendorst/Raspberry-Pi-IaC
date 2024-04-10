#!/usr/bin/python3
# Fetches the public IP and updates the record on Cloudflare which is provided as an argument
# to match this public record.
import requests
import logging
import sys
import configparser
import argparse
import dns.resolver


logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(levelname)s - %(message)s')

def get_public_IP():
    logging.info('Retrieving the public IP for this machine...')
    response = requests.get('https://api.ipify.org?format=json')

    if response.status_code != 200:
        raise Exception('Something went wrong requesting the public ip, exiting...')

    public_ip = response.json()['ip']
    logging.info(f'The public IP address for this machine is: {public_ip}.')
    return public_ip

def resolve_name(domain):
    logging.info(f'Resolving {domain}...')
    try:
        result = dns.resolver.resolve(domain, 'A')
    except dns.resolver.NXDOMAIN:
        logging.error(f'No DNS record exists for {domain}, configure it first before using this ddns script. Exiting...')
        exit(1)

    resolved_address = result[0].address
    logging.info(f'Resolved {domain} to: {resolved_address}.')
    return resolved_address

def get_zone_id(domain):
    response = requests.get(f'https://api.cloudflare.com/client/v4/zones?name={domain}', headers=cloudflare_request_headers)

    if response.status_code != 200:
        raise Exception('Something went wrong requesting the zone of the domain on Cloudflare...')

    zone_id = response.json()['result'][0]['id']
    return zone_id

def get_record_id(zoneId, record):
    logging.debug('Getting record id...')
    response = requests.get(f'https://api.cloudflare.com/client/v4/zones/{zoneId}/dns_records?name={record}', headers=cloudflare_request_headers)

    if response.status_code != 200:
        raise Exception('Something went wrong requesting the record id of the domain name on Cloudflare...')

    return response.json()['result'][0]['id']


def change_record(subdomain, zoneId, recordId):
    logging.info(f'Changing record for {subdomain} to point to {publicIP}...')
    dns_change_response = requests.put(f'https://api.cloudflare.com/client/v4/zones/{zoneId}/dns_records/{recordId}',
                    headers=cloudflare_request_headers,
                    json={
                        'content': publicIP,
                        'name': subdomain,
                        'proxied': False,
                        'type': 'A',
                        'comment': 'Is set to change with my DDNS script (on the Raspberry Pi).',
                        'ttl': 1 # Meaning "Automatic", see: https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-update-dns-record
                    })

    if dns_change_response.status_code != 200:
        raise Exception('Something went wrong updating the dns record...')

    logging.info('Succesfully updated the record ✅!')

parser = argparse.ArgumentParser()
parser.add_argument('subdomain')
parser.add_argument('-c', '--config-file', dest='config')

args = parser.parse_args()

subdomain = args.subdomain
config_file_path = args.config

fixedTopLevelDomain = 'kleinendorst.info'
fullDomainName = f'{subdomain}.{fixedTopLevelDomain}'

config = configparser.ConfigParser()
config.read(config_file_path)

cloudflare_api_credentials = config['credentials']['dns_cloudflare_token']
cloudflare_request_headers = {'Content-Type': 'application/json', 'Authorization': f'Bearer {cloudflare_api_credentials}'}

log_path = config.get('log_changes', 'log_path', fallback=None)
if log_path is not None:
    log_path = config['log_changes']['log_path']
    logging.info(f'Logging DNS name changes to {log_path} on IP updates.')

resolvedIP = resolve_name(fullDomainName)
publicIP = get_public_IP()
if resolvedIP == publicIP:
    logging.info(f'Currently resolved name already matches the public ip ({publicIP}), exiting...')
    exit(0)

zoneId = get_zone_id(fixedTopLevelDomain)
recordId = get_record_id(zoneId, fullDomainName)
change_record(subdomain, zoneId, recordId)

with open(log_path, 'a+') as log_file:
    msg = f'Address for FQDN {fullDomainName} altered from: {resolvedIP} - {publicIP}.'
    logging.info(f'Writing: "{msg}" to log file at {log_path}...')
    log_file.write(msg + '\n')
