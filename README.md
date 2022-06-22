# The Control-Core Mediator for Closed-Loop Neuromodulation Control Systems

The Control-Core Mediator is built with is Python-3.7. It is the core component that makes the distributed executions a reality in the Control-Core framework.


# Building Mediator Container

Log in to the server which you like to configure as the Mediator.

If it is a remote AWS server, use ssh as below, assuming x.x.x.x to be the IP address of your server.
````
$ ssh -i "controlcore.pem" ubuntu@x.x.x.x
````
Perform Git clone if this is the first time you are configuring the Server
````
$ git clone git@github.com:ControlCore-Project/Mediator.git
````

First build the Docker Container of the Mediator.
````
$ git pull

$ sudo docker build -t mediator .
````

# Running Control-Core Mediator with Kong as containers

If you are already running Mediator, make sure to stop and clear existing Mediator container as it is likely conflict with the port. If there is Kong gateway running in default ports, stop and clear it too.
````
$ docker stop mediator
$ docker rm mediator
$ docker stop kong
$ docker rm kong
````

Start and configure Cassandra container for Kong API.
````
$ docker run -d --name kong-database \
                -p 9042:9042 \
                cassandra:3


$ docker run --rm \
    --link kong-database:kong-database \
    -e "KONG_DATABASE=cassandra" \
    -e "KONG_PG_HOST=kong-database" \
    -e "KONG_PG_USER=kong" \
    -e "KONG_PG_PASSWORD=kong" \
    -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
    kong kong migrations bootstrap
````

Start Kong
````
$ docker run -d --name kong \
    --link kong-database:kong-database \
    -e "KONG_DATABASE=cassandra" \
    -e "KONG_PG_HOST=kong-database" \
    -e "KONG_PG_PASSWORD=kong" \
    -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
    -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
    -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
    -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
    -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
    -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
    -p 80:8000 \
    -p 8443:8443 \
    -p 8001:8001 \
    -p 8444:8444 \
    kong
````

Start Mediator container
````
$ nohup sudo docker run --name mediator -p 8090:8081 mediator > controlcore.out &
````

Delete if there is a previously configured Kong service. If not, skip this step. First you need to find the ID-VALUE for the route with a GET command before deleting the route and service.
````
$ curl -X GET "http://localhost:8001/services/mediator/routes"
````
Use the ID output from above to issue the delete command as below (issue this only if you have a previous conflicting service definiton in kong. Otherwise, skip this step):
````
$ curl -X DELETE "http://localhost:8001/services/mediator/routes/ID-VALUE"

$ curl -X DELETE "http://localhost:8001/services/mediator/"
````

Define Kong Service and Route.

First Configure a Kong service, replacing the variable "private-ip" with the private IP address of your server below.
````
$ curl -i -X POST --url http://localhost:8001/services/ --data 'name=mediator' --data 'url=http://private-ip:8090'
````
Then configure route to the service
````
$ curl -i -X POST --url http://localhost:8001/services/mediator/routes --data 'paths=/'
````

Now, controlcore.org is routed through the Kong APIs.

# Configuring Secondary Kong (Only if the API Key generation is handled publicly)
*Please ignore this section if the API key generation is not managed externally, exposing the Kong's admin APIs securely to the public. Therefore, this section is largely optional.*

Start Secondary Kong that functions as an Admin Kong
```
$ docker run -d --name kongadmin \
     --link kong-database:kong-database \
     -e "KONG_DATABASE=cassandra" \
     -e "KONG_PG_HOST=kong-database" \
     -e "KONG_PG_PASSWORD=kong" \
     -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
     -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
     -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
     -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
     -p 8002:8000 \
     -p 9443:8443 \
     -p 9001:8001 \
     -p 9444:8444 \
     kong
````

Configure API definitions

Run the service_config.sh script, after replacing the variable "private-ip" with the private IP address of your server.
````
$ bash service_config.sh
````
Define the Consumer Creation API:


Step 1: Create a service for consumers, replacing the variable "private-ip" with the private IP address of your server below:

````
$ curl -i -X POST --url http://localhost:9001/services/ --data 'name=consumers' --data 'url=http://private-ip:8001/consumers'
````

Step 2: Create a route:

````
$ curl -i -X POST --url http://localhost:9001/services/consumers/routes --data 'paths=/consumers'
````

Step 3: Create a consumer "testuser" from O2S2Parc:

Using Python client
````
$ pip3 install requests
````

Change the value of global variable "tenant" to your preferred string such as your OSPARC ID.

Then run the APIKeyGen.py, after replacing the value www.project-url.org with the actual URL of your project (i.e., the URL where Mediator is deployed).

Take note of the API Key output.

````
python3 APIKeyGen.py
````
Or using curl, assuming www.project-url.org to be the web URL where the Mediator is hosted.

format:
````
$ curl -d "username=SOME_ID&custom_id=SOME_CUSTOM_ID" www.project-url.org:8002/consumers/
````
sample:
````
$ curl -d "username=testuser&custom_id=testuser" www.project-url.org:8002/consumers/
````

Step 4: Create a key:

format:
````
$ curl -X POST www.project-url.org:8002/consumers/{consumer}/key-auth
````

sample:
````
$ curl -X POST www.project-url.org:8002/consumers/testuser/key-auth
````

Step 5: Test with the newly created key.

http://www.project-url.org/homepage?apikey=xxxxxxxxxx


# Troubleshooting the Mediator

Connect to the Server VM
````
$ ssh -i "controlcore.pem" ubuntu@x.x.x.x
````
Check the Server logs.
````
$ tail -f controlcore.out
````
or
````
$ sudo docker logs mediator -f
````
Find the Mediator docker container
````
$ sudo docker ps
````
CONTAINER ID        IMAGE               COMMAND              CREATED             STATUS              PORTS                NAMES
dfdd3b3d3308        mediator            "python Server.py"   38 minutes ago      Up 38 minutes       0.0.0.0:80->80/tcp   mediator

Access the container
````
$ sudo docker exec -it dfdd /bin/bash
````



# Citing the CONTROL-CORE Mediator

If you use the CONTROL-CORE Mediator in your research, please cite the below paper:

* Kathiravelu, P., Arnold, M., Fleischer, J., Yao, Y., Awasthi, S., Goel, A. K., Branen, A., Sarikhani, P., Kumar, G., Kothare, M. V., and Mahmoudi, B. **CONTROL-CORE: A Framework for Simulation and Design of Closed-Loop Peripheral Neuromodulation Control Systems**. In IEEE Access. March 2022. https://doi.org/10.1109/ACCESS.2022.3161471 
