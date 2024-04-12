import logging
import requests
import dns.resolver


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
