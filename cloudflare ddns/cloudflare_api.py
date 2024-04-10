import requests
import logging

class CloudflareAPIException(Exception):
    def __init__(self, message, response) -> None:
        full_message = f'Cloudflare request failed (code: {response.status_code}): {message}\n\nServer body:\n{response.text}'
        super().__init__(full_message)

class CloudFlare:
    def __init__(self, api_token):
        self.headers = {'Content-Type': 'application/json', 'Authorization': f'Bearer {api_token}'}

    def get_zone_id(self, domain):
        response = requests.get(f'https://api.cloudflare.com/client/v4/zones?name={domain}', headers=self.headers)

        if response.status_code != 200:
            raise CloudflareAPIException('Something went wrong requesting the zone of the domain on Cloudflare...', response)

        zone_id = response.json()['result'][0]['id']
        return zone_id

    def get_record_id(self, zoneId, record):
        logging.debug('Getting record id...')
        response = requests.get(f'https://api.cloudflare.com/client/v4/zones/{zoneId}/dns_records?name={record}', headers=self.headers)

        if response.status_code != 200:
            raise CloudflareAPIException('Something went wrong requesting the record id of the domain name on Cloudflare...', response)

        return response.json()['result'][0]['id']


    def change_record(self, subdomain, zoneId, recordId, targetIp):
        logging.info(f'Changing record for {subdomain} to point to {targetIp}...')
        response = requests.put(f'https://api.cloudflare.com/client/v4/zones/{zoneId}/dns_records/{recordId}',
                        headers=self.headers,
                        json={
                            'content': targetIp,
                            'name': subdomain,
                            'proxied': False,
                            'type': 'A',
                            'comment': 'Is set to change with my DDNS script (on the Raspberry Pi).',
                            'ttl': 1 # Meaning "Automatic", see: https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-update-dns-record
                        })

        if response.status_code != 200:
            raise CloudflareAPIException('Something went wrong updating the dns record...', response)

        logging.info('Succesfully updated the record ✅!')
