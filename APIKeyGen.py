import requests
import logging
import json

logging.basicConfig(level=logging.INFO, format='%(message)s')
  
tenant = 'tester-tenant'


def convert_to_json(response):
    resp = response.text
    logging.debug(resp)
    resp_json = json.loads(resp)
    logging.debug(resp_json)
    return resp_json


def generate_key(tenant):
    data = {
            'username': tenant,
            'custom_id': tenant
            }

    response = requests.get('http://www.project-url.org:8002/consumers/' + tenant + '/key-auth')

    resp_json = convert_to_json(response)
    
    if('data' in resp_json):
        logging.info(resp_json['data'][0]['key'])
    else:
        response = requests.post('http://www.project-url.org:8002/consumers/', data=data)
        logging.debug(response.text)
        response = requests.post('http://www.project-url.org:8002/consumers/' + tenant + '/key-auth')
        resp_json = convert_to_json(response)
        logging.info(resp_json['key'])


if __name__ == "__main__":
    generate_key(tenant)
