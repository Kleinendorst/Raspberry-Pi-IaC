#!/usr/bin/bash
source ~/bin/cloudflare_ddns/venv/bin/activate
python3 ~/bin/cloudflare_ddns/cloudflare_ddns.py --config-file ~/cloudflare_ddns/ddns_config.ini $@
