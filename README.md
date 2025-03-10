# The CONTROL-CORE Mediator for Closed-Loop Neuromodulation Control Systems

The CONTROL-CORE Mediator is built with Python-3.7. It is the core component that makes distributed executions a reality in the CONTROL-CORE framework. The Mediator enables distributed execution of the CONTROL-CORE studies. As a containerized architecture, Mediator is easy to install, together with a Kong API Gateway-based authentication mechanism. The Mediator uses simple REST calls and file-sharing mechanisms for the distributed execution of the studies.

---

## Building Mediator Container

Log in to the server which you like to configure as the Mediator.

If it is a remote AWS server, use ssh as below, assuming `x.x.x.x` to be the IP address of your server.

```bash
$ ssh -i "controlcore.pem" ubuntu@x.x.x.x
```

Perform Git clone if this is the first time you are configuring the Server.

```bash
$ git clone git@github.com:ControlCore-Project/Mediator.git
```

First, build the Docker Container of the Mediator.

```bash
$ cd Mediator
```

Get the latest version if the clone was old.

```bash
$ git pull
$ sudo docker build -t mediator .
```

---

## Running CONTROL-CORE Mediator with Kong as Containers

If you are already running Mediator, make sure to stop and clear the existing Mediator container as it may conflict with the port. If there is a Kong gateway running in default ports, stop and clear it too. The same goes for the Kong Database.

```bash
$ sudo docker stop mediator
$ sudo docker rm mediator
$ sudo docker stop kong
$ sudo docker rm kong
$ sudo docker stop kong-database
$ sudo docker rm kong-database
```

Start and configure PostgreSQL container for Kong API.

```bash
$ sudo docker run -d --name kong-database \
                -p 5432:5432 \
                -e POSTGRES_USER=kong \
                -e POSTGRES_PASSWORD=kong \
                -e POSTGRES_DB=kong \
                postgres:latest
```

Wait a minute or two for PostgreSQL to start.

```bash
$ sudo docker run --rm \
    --link kong-database:kong-database \
    -e "KONG_DATABASE=postgres" \
    -e "KONG_PG_HOST=kong-database" \
    -e "KONG_PG_USER=kong" \
    -e "KONG_PG_PASSWORD=kong" \
    kong/kong-gateway:latest kong migrations bootstrap
```

Start Kong.

```bash
$ sudo docker run -d --name kong \
    --link kong-database:kong-database \
    -e "KONG_DATABASE=postgres" \
    -e "KONG_PG_HOST=kong-database" \
    -e "KONG_PG_USER=kong" \
    -e "KONG_PG_PASSWORD=kong" \
    -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
    -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
    -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
    -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
    -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
    -p 80:8000 \
    -p 8443:8443 \
    -p 8001:8001 \
    -p 8444:8444 \
    kong/kong-gateway:latest
```

Start Mediator container.

```bash
$ nohup sudo docker run --name mediator -p 8090:8081 mediator > controlcore.out &
```

Delete if there is a previously configured Kong service. If not, skip this step. First, find the ID-VALUE for the route with a GET command before deleting the route and service.

```bash
$ curl -X GET "http://localhost:8001/services/mediator/routes"
```

Use the ID output from above to issue the delete command below (issue this only if you have a previous conflicting service definition in Kong. Otherwise, skip this step):

```bash
$ curl -X DELETE "http://localhost:8001/services/mediator/routes/ID-VALUE"
$ curl -X DELETE "http://localhost:8001/services/mediator/"
```

Define Kong Service and Route.

First, configure a Kong service, replacing the variable `private-ip` with the private IP address of your server below.

```bash
$ curl -i -X POST --url http://localhost:8001/services/ --data 'name=mediator' --data 'url=http://private-ip:8090'
```

Then configure the route to the service.

```bash
$ curl -i -X POST --url http://localhost:8001/services/mediator/routes --data 'paths=/'
```

Now, `controlcore.org` is routed through the Kong APIs.

---

## Configuring Secondary Kong (Only if the API Key generation is handled publicly)

*This section assumes the API key generation is managed externally, exposing Kong's admin APIs securely to the public. Otherwise, the secondary Kong is not necessary, and the API Keys can be configured directly, skipping this step, and adapting accordingly.*

Start Secondary Kong that functions as an Admin Kong.

```bash
$ docker run -d --name kongadmin \
     --link kong-database:kong-database \
     -e "KONG_DATABASE=postgres" \
     -e "KONG_PG_HOST=kong-database" \
     -e "KONG_PG_USER=kong" \
     -e "KONG_PG_PASSWORD=kong" \
     -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
     -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
     -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
     -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
     -p 8002:8000 \
     -p 9443:8443 \
     -p 9001:8001 \
     -p 9444:8444 \
     kong/kong-gateway:latest
```

Configure API definitions.

Run the `service_config.sh` script, after replacing the variable `private-ip` with the private IP address of your server.

```bash
$ bash service_config.sh
```

Define the Consumer Creation API:

**Step 1:** Create a service for consumers, replacing the variable `private-ip` with the private IP address of your server below:

```bash
$ curl -i -X POST --url http://localhost:9001/services/ --data 'name=consumers' --data 'url=http://private-ip:8001/consumers'
```

**Step 2:** Create a route:

```bash
$ curl -i -X POST --url http://localhost:9001/services/consumers/routes --data 'paths=/consumers'
```

**Step 3:** Create a consumer "testuser" from O2S2Parc:

Using Python client:

```bash
$ pip3 install requests
```

Change the value of the global variable `tenant` to your preferred string such as your OSPARC ID.

Then run the `APIKeyGen.py`, after replacing the value `www.project-url.org` with the actual URL of your project (i.e., the URL where Mediator is deployed). If the `APIKeyGen.py` is run locally, replace it with `localhost` instead.

Take note of the API Key output.

```bash
$ python3 APIKeyGen.py
```

Or using curl, assuming `www.project-url.org` to be the web URL where the Mediator is hosted.

Format:

```bash
$ curl -d "username=SOME_ID&custom_id=SOME_CUSTOM_ID" www.project-url.org:8002/consumers/
```

Sample:

```bash
$ curl -d "username=testuser&custom_id=testuser" www.project-url.org:8002/consumers/
```

**Step 4:** Create a key:

Format:

```bash
$ curl -X POST www.project-url.org:8002/consumers/{consumer}/key-auth
```

Sample:

```bash
$ curl -X POST www.project-url.org:8002/consumers/testuser/key-auth
```

**Step 5:** Test with the newly created key.

```
http://www.project-url.org/homepage?apikey=xxxxxxxxxx
```

---

## Troubleshooting the Mediator

Connect to the Server VM.

```bash
$ ssh -i "controlcore.pem" ubuntu@x.x.x.x
```

Check the Server logs.

```bash
$ tail -f controlcore.out
```

or

```bash
$ sudo docker logs mediator -f
```

Find the Mediator docker container.

```bash
$ sudo docker ps
```

Access the container.

```bash
$ sudo docker exec -it <CONTAINER_ID> /bin/bash
```

---

## Start the containers if they are stopped on their own.

```bash
$ sudo docker start kong-database
$ sudo docker start kong
$ sudo docker start mediator
```

---

## Citing the CONTROL-CORE Mediator

If you use the CONTROL-CORE Mediator in your research, please cite the below paper:

* Kathiravelu, P., Arnold, M., Fleischer, J., Yao, Y., Awasthi, S., Goel, A. K., Branen, A., Sarikhani, P., Kumar, G., Kothare, M. V., and Mahmoudi, B. **CONTROL-CORE: A Framework for Simulation and Design of Closed-Loop Peripheral Neuromodulation Control Systems**. In IEEE Access. March 2022. https://doi.org/10.1109/ACCESS.2022.3161471
