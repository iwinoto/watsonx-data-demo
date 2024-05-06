# 6/03/2024
## IBM watsonx.data for Technical Sales L3 - Lab Guide

## Stand and Deliver Demo
### Client: Life Sciences organisation
A life sciences start-up. They have developed a cloud deployed software platform that controls the supply chain of biological material products including sperm and embryo. The supply chain collects biological material from donors. The material is frozen for transport. The frozen material is transported. At its first destination it may be stored or defrosted for further processing.

In either case, the devices which perform the function to feeze or thaw the material collect data during the process. The data is stored on the platform in an RDBMS type data store. Sensor data attached to the material also collects environmental data as the material is transported or stored. Material environmental data is stored in the same RDBMS and the data from freezing and thawing devices.

### Pain point
The enterprise would like to analyse the data collected to learn about the factors impacting material viability through it's lifecycle. This is **important** to feedback in to the freezing and thawing steps to maintain an improve material viability in all stages of handling and storage. The modelling used to analyse the data is not a pain point to the enterprise. What is a pain point is how the data is fed into the model efficiently and without impacting other critical business processes which rely on the data store.

Because data is currently stored in RDBMS, it is challenging for Vitrafy to access the data without impacting platform performance. Additionally, analysis does not require access to realtime data as results are not impacted by the presence of the most recent data points.

A solution is needed to:
* easily offload data to an offline repository for analysis on a regular basis.
* Once in the offline repository, the data needs to be easily accessible to data scientists and modelling services via a simple API that allows for analysis of massive mounts of data.
* use common data science tools so team does not need to learn new tools or can easily access resources
* because the enterprise is a startup business, the platform solution is likely to evolve rapidly in response to growing the business and client demand. This may result in rapid changes to the data schema and data storage landscape; that is, other databases may be added to the RDBMS or other storage technology such as document based storage may be added to the solution.
* access to live data for analysis can disrupt platform performance and impact user experience
* Also runtime OLTP data store schemas tend to be normalised to improve DB performance. However data scientist typically need access to un-normalised data to be able to perform longitudinal analysis of data for pattern extraction and modelling
* Data analysis would be most easily done if data is in a lake house type system where it can be off-line and combined with other data.
* Moving data from OTLP stores to lake-houses can be time consuming and expensive. Also requires governance to maintain data currency
* watsonx.data is an open lakehouse implementation that can solve these problems 

### Watsonx.data value proposition
* Modernise storage by moving data from on-line storage to data lake archive storage.
* Data move can be either ad-hoc or scheduled.
* Connects to S3 compliant low cost object store for data storage.
* Connects to various storage technologies using common standards such as S3 or open source for data lake.
* Implements open source standards for data lake cataloguing
* Provides open source SQL engines to efficiently execute queries on data lakes and lakehouses
* Provides library of open source query engines that are popular in the market so data scientist do not need to learn new proprietary tools
* allows for offloading existing data from a client’s enterprise data warehouse (EDW), where the performance requirements and/or frequency with which the data is accessed don’t justify the costs of having that data in the warehouse (keep in mind that costs aren’t limited to the data storage itself; there are costs in preparing and moving data into the warehouse, additional storage costs for larger backup images, the impact of running relatively low priority workloads at the same time as higher priority workloads, and so on).
* queries can combine data in the warehouse with the data in the lakehouse. This provides clients with complete flexibility in where they store their data.
* Presto in watsonx.data can currently connect to IBM Db2, Netezza, Apache Kafka, Elasticsearch, MongoDB, MySQL, PostgreSQL, SAP HANA, SingleStore, Snowflake, SQL Server, Teradata, and others through a custom connector

### Demonstrating how watsonx.data relieves the pain points
#### Preparation
* create watsonx.demo.events table in postgreSQL
  * create the `watsonx` database
  * create the `watsonx.demo.events` table, populate with data and run a sample query.
  ```
  $ export PGPASSWORD=password
  $ /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U username -e -c 'CREATE DATABASE watsonx'
  $ /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U username -d watsonx -e -f ./data/client\ demo-create\ events\ table.sql
  ```
* create demo bucket in minio
  * retrieve minio S3 access key (user name)
    ```
    docker exec ibm-lh-presto printenv | grep LH_S3_ACCESS_KEY | sed 's/.*=//'
    261876628da42a95863235df
    ```
    Should return `261876628da42a95863235df`
  * Retrieve minio S3 secret key (password)
    ```
    docker exec ibm-lh-presto printenv | grep LH_S3_SECRET_KEY | sed 's/.*=//'
    ```
    should return `50fe0a65d9e5bcbb3110124a`.
  * Make sure minio client alias is set up for watsonx docker environment. `mc alias list watson-minio` should return as below
    ```
    $ mc alias list watsonx-minio
    watsonx-minio
      URL       : http://localhost:9000
      AccessKey : 261876628da42a95863235df
      SecretKey : 50fe0a65d9e5bcbb3110124a
      API       : s3v4
      Path      : auto
    ```
    If it is not set correctly, then create the alias with
    ```
    mc alias set watsonx-minio http://localhost:9000 261876628da42a95863235df 50fe0a65d9e5bcbb3110124a
    ```
  * Create the `demo-devices` bucket
    ```
    mc mb watson-minio/demo-devices
    ```
    Check that the bucket has been created
    ```
    mc ls watsonx-minio
    ```
  * Copy `demo.devices.json` file to the `demo-devices bucket`
    ```
    mc cp ./data/demo.devices.json watsonx-minio/demo-devices/devices.json
    ```
    data file should be visible through minio console and from the command line
    ```
    mc ls watsonx-minio/demo-devices
    ```
* Explore watsonx.data lakehouse console
  * open watsonx.data [console](https://localhost:9443). It may be necessary to accept the unsafe location.
  * login in with user `ibmlhadmin` and password `password`
* Add a catalog entry for postgreSQL to view the device events data
* Add an hive catalog entry to view the device data from minio.
  * start the presto CLI
    ```
    ~/dev/watsonx.data/ibm-lh-dev/bin/presto-cli --catalog hive_data
    ```
  * Create a schema for the demo data called `demo`
    ```
    create schema if not exists demo with (location='s3a://hive-bucket/demo');
    ```
  * confirm the schema was created
    ```
    show schemas;
    ```
  * create a new table to hold devices information
    ```
    create table demo.devices (id varchar, location.latitude float, location.longitude float, owner varchar, status varchar);
    ```
  * confirm the table was created
    ```
    show tables from demo;
    ```

#### Script
* Get the PostgreSQL server password with this command `docker exec ibm-lh-postgres printenv | grep POSTGRES_PASSWORD | sed 's/.*=//'`
* run select query on `watsonx.demo.events`
    ```
    PGPASSWORD=*<Password from step previous step>* && /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U admin -d watsonx -c "SELECT * from demo.events WHERE source_id LIKE 'vtu-%'"
    ```
* point out data from many devices over time. For demo purposes, there is only temperature data, but schema can accommodate data of infinite types from infinite sources.
* data scientist want to apply machine learning models against this data
* we'll import this data into watsonx.data
* First we need to discover important information about the PostgreSQL installation
  1. open a command terminal
  2. enter `docker network inspect ibm-lh-network | jq -r '.[0].Containers | map({"Name" : .Name, "IP" : .IPv4Address}).[] | select( .Name == "ibm-lh-postgres")'`
  3. Note the value for `IP`. This is the IP address for the container running the PostgreSQL server.
* Add the PostgreSQL database to the lakehouse
  1. Select the *Infrastructure Manager*
  2. Click *Add Component*, select *Add Database*
  3. In the *Add Database* dialogue enter the following
     *  Database type: *PostgreSQL* (it can be found under the From Others section)
     *  Database name: *demo*
     *  Display name: *PostgreSQLDB*
     *  Hostname: *<IP Address from step 3>*
     *  Port: *5432*
     *  Username: *admin*
     *  Password: *<Password from step 4>*
     *  Catalog name: pgcatalog
* Select *Data Manager* from the left-side menu
* Expand *pgcatalog*
* Show events table information, including schema
* Show sample table data for events table.
* We now have a copy of the *demo.events* data that can be analysed without impacting production performance. This was created with the open source Presto engine.
* In reality, an enterprise would create a schema that is a combination of data from different data sources, which may be different technologies.
* For example, device data may come from an object store.

## Client "call to action"


## Notes
### Running Watsonx.data developer edition locally
Watsonx.data can be run as containers on podman. Instructions are in the [wastsonx.data documentation](https://www.ibm.com/docs/en/watsonxdata/1.1.x?topic=edition-installing-watsonxdata-developer-version).

There are issues with the instructions and scripts that need to be resolved.
* If running MacOSX Silicon architecture, then need to follow pre-requisites for Silicon which require using Docker CE with Colima VM engine. This does not work with Podman.
* When logging in, Docker may need to have appropriate keychain helper for the host. In the case of MacOSX, this requires setting up the keychain. More information is in [docker login](https://docs.docker.com/reference/cli/docker/login/).
  * Use brew to install the `docker-credential-helper` package
    `$ brew install docker-credential-helper`
  * edit `~/.docker/config.json` to replace `credsStore` key with `osxkeychain`
    `"credsStore": "osxkeychain"`
* The `start` command to start the watsonx.data containers calls `healthChecks.sh` which will fail in several areas.
  1. The functions to check for presto readiness (`presto_check` and `presto_check_retries`) uses the `base64` command with the `-w` option to set the character width of the output. The version of `base64` may not support the `-w` option. Replace the line to remove the `-w` option.
  2. Also in the functions to check for presto readiness (`presto_check` and `presto_check_retries`), the code to check for http status is error prone. The first few times when a request to the presto container is made, the container services are still starting and not ready to respond to requests. The http status code will be `000`. This means the substring to extract the characters from the response after the http status will return an error (`substring expression < 0`). The code should be modified to check the length of the string to make sure the substring index does not try to index beyond the string length. Use the following code:
  ```
  apiResponse=$($DRY_RUN $dockerexe exec $args $containerID /bin/bash -c "curl -s -w '%{http_code}' --location --request GET 'https://localhost:8443/v1/info' -k --header 'Content-Type: application/json' --header 'Authorization: Basic $encodedCredentials' --data ''")
  echo "API Response: $apiResponse"
  apiResponseLen=${#apiResponse}
  echo "API Response length: $apiResponseLen"
  if [[ $apiResponseLen -ge 3 ]]; then
    httpCode=${apiResponse: -3}  # Extract last 3 characters (HTTP code)
    responseBody=${apiResponse:0: apiResponseLen - 3}  # Remove last 3 characters (HTTP code)
  fi

  echo "HTTP Code: $httpCode"
  echo "Response Body: $responseBody"
  body="${apiResponse%$httpCode}"
  ```
  3. Postgres service is not available from the host. This is because the default run mode does not expose Postgres service ports. Set the `LH_RUN_MODE` to `diag` when setting the other environment variables at the start of the instructions.
  ```
  ## diag run mode so developer can access postgres, minio and hive containers from host.
  export LH_RUN_MODE=diag
  ```

### Testing PostgreSQL locally
For local testing of postgreSQL, usd podman to run a container with postgreSQL. This can be used to test the creation of demo databases.

Refer to [article](https://medium.com/@pawanpg0963/run-postgresql-with-podman-as-docker-container-86ad392349d1)

```
#if podman machine does not already exist
$ podman machine init

$ podman machine start
```

Start postgreSQL container

```
$ podman pull postgres
$ mkdir -p ./data
$ podman run --name postgres -e POSTGRES_USER=username -e
POSTGRES_PASSWORD=password -v ./data -p 5432:5432 -d postgres

```

Run postgreSQL client from terminal:
```
$ PGPASSWORD=password /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U username
```

### Tesing DB2 locally
Run DB2 Community edition in a container. This [article](https://www.ibm.com/docs/en/db2/11.5?topic=system-windows) describes how. The article uses docker, but can also be run in podman. Just replace `docker` command with `podman`.

For work around to issues with MacOS Silicon, see [this thread](https://community.ibm.com/community/user/datamanagement/discussion/db2-luw-115xx-mac-m1-ready#bm77e71277-b647-4220-96ca-2f4606270808)

Pull and start container on the `ibm-lh-network` using this command:

```
$ cd ~/dev/db2
$ source docker_env.sh
$ docker pull icr.io/db2_community/db2
$ docker run -h db2server --name db2server --restart=always --detach --privileged=true -p 50000:50000 --platform=$DOCKER_DEFAULT_PLATFORM --network ibm-lh-network --env-file .env_list -v $DB_MOUNT:/database icr.io/db2_community/db2
```

### Demo data
#### Device events
`demo.events.csv`

#### Devices
`demo.devices.json`
