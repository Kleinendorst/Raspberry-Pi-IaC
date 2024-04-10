#!/usr/bin/python3
# Fetches the public IP and updates the record on Cloudflare which is provided as an argument
# to match this public record.
import logging
import sys
import configparser
import argparse
from cloudflare_api import CloudFlare
from ip_helpers import get_public_IP, resolve_name


logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(levelname)s - %(message)s')

parser = argparse.ArgumentParser()
parser.add_argument('subdomains', nargs='+')
parser.add_argument('-c', '--config-file', dest='config')

args = parser.parse_args()


config_file_path = args.config

config = configparser.ConfigParser()
config.read(config_file_path)

cloudflare_api_credentials = config['credentials']['dns_cloudflare_token']
cloudflare = CloudFlare(cloudflare_api_credentials)

log_path = config.get('log_changes', 'log_path', fallback=None)
if log_path is not None:
    log_path = config['log_changes']['log_path']
    logging.info(f'Logging DNS name changes to {log_path} on IP updates.')

publicIP = get_public_IP()
subdomains = args.subdomains
fixedTopLevelDomain = 'kleinendorst.info'

for subdomain in subdomains:
    fullDomainName = f'{subdomain}.{fixedTopLevelDomain}'

    resolvedIP = resolve_name(fullDomainName)
    if resolvedIP == publicIP:
        logging.info(f'Currently resolved name already matches the public ip ({publicIP}), exiting...')
        exit(0)

    zoneId = cloudflare.get_zone_id(fixedTopLevelDomain)
    recordId = cloudflare.get_record_id(zoneId, fullDomainName)
    cloudflare.change_record(subdomain, zoneId, recordId, publicIP)

    with open(log_path, 'a+') as log_file:
        msg = f'Address for FQDN {fullDomainName} altered from: {resolvedIP} - {publicIP}.'
        logging.info(f'Writing: "{msg}" to log file at {log_path}...')
        log_file.write(msg + '\n')
