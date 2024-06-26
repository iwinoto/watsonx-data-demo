# IBM watsonx.data Demonstration

## Fictional Client: Life Sciences organisation
A life sciences start-up. They have developed a cloud deployed software platform that controls the supply chain of biological material products such as blood, sperm and embryo. The supply chain collects biological material from donors. The material is frozen and is transported. At its first destination it may be stored or defrosted for further processing.

In either case, the devices which perform the function to feeze or thaw the material collect data during the process. The data is stored on the platform in an RDBMS type data store. Sensor data attached to the material also collects environmental data as the material is transported or stored. Material environmental data is stored in the same RDBMS as the data from freezing and thawing devices.

## Pain point
The enterprise would like to analyse the data collected to learn about the factors impacting material viability through it's lifecycle. This is **important** to feedback in to the freezing and thawing steps to maintain an improve material quality through all stages of handling and storage. The enterpise has developed a machine learning model to analyse the data from devices and suggest adjustment to device parameters which can improve quality. What is a pain point is how the data is fed into the model efficiently and without impacting other critical business processes which rely on the data store.

Because data is currently stored in RDBMS, it is challenging for Vitrafy to access the data without impacting platform performance. Additionally, analysis does not require access to realtime data as results are not impacted by the presence of the most recent data points.

In the future the enterprise envisages that data from other sources will be incorporated into the ML model to further improve outcomes.

A solution is needed to:
* easily offload data to an offline repository for analysis on a regular basis.
* Once in the offline repository, the data needs to be easily accessible to data scientists and modelling services via a simple API that allows for analysis of massive mounts of data.
* use common data science tools so team does not need to learn new tools or can easily access resources
* because the enterprise is a startup business, the platform solution is likely to evolve rapidly in response to growing the business and client demand. This may result in rapid changes to the data schema and data storage landscape; that is, other databases may be added to the RDBMS or other storage technology such as document based storage may be added to the solution.
* access to live data for analysis can disrupt platform performance and impact user experience
* Also runtime OLTP data store schemas tend to be normalised to improve DB performance. However data scientist typically need access to un-normalised data to be able to perform longitudinal analysis of data for pattern extraction and modelling

Data analysis would be most easily done if data is in a lake house type system where it can be off-line and combined with other data.

Moving data from OTLP stores to lake-houses can be time consuming and expensive. Also requires governance to maintain data currency
*watsonx.data* is an open lakehouse implementation that can solve these problems 

## Watsonx.data value proposition
* Modernise storage by moving data from on-line storage to data lake archive storage.
* Data move can be either ad-hoc or scheduled.
* Connects to S3 compliant low cost object store for data storage.
* Connects to various storage technologies using common standards such as S3 or open source for data lake.
* Implements open source standards for data lake cataloguing
* Provides open source SQL engines like Presto and Spark to efficiently execute queries on data lakes and lakehouses
* Connects with many open source and proprietary data stores and services (postgres, DB2, Snowflake, S3 object stores, other data warehouses)
* Provides library of open source query engines that are popular in the market so data scientist do not need to learn new proprietary tools
* Connects with powerful opensource tools like Hive Meta Store and Iceberg which provides tooles like time travel and alterations to tables
* Can be part of an end-to-end AI pipeline with integration to watsonx.ai, Studio and other products
* Hybrid deploymention opotions - on/off-prem, PaaS or SaaS
* allows for offloading existing data from a client’s enterprise data warehouse (EDW), where the performance requirements and/or frequency with which the data is accessed don’t justify the costs of having that data in the warehouse (keep in mind that costs aren’t limited to the data storage itself; there are costs in preparing and moving data into the warehouse, additional storage costs for larger backup images, the impact of running relatively low priority workloads at the same time as higher priority workloads, and so on).
* queries can combine data in the warehouse with the data in the lakehouse. This provides clients with complete flexibility in where they store their data.
* Presto in watsonx.data can currently connect to IBM Db2, Netezza, Apache Kafka, Elasticsearch, MongoDB, MySQL, PostgreSQL, SAP HANA, SingleStore, Snowflake, SQL Server, Teradata, and others through a custom connector

## Script to demonstrate how watsonx.data relieves the pain points
### Preparation
* Set up *watsonx.data Developer Edition* according to [notes below](#running-watsonxdata-developer-edition-locally).
* create watsonx.demo.events table in postgreSQL
  1. Retrieve the postgreSQL admin user password, and set to `PGPASSWORD` environment variable
    ```
    export PGPASSWORD=$(docker exec ibm-lh-postgres printenv | grep POSTGRES_PASSWORD | sed 's/.*=//')
    ```

  2. create the `watsonx` database using postgreSQL CLI
    ```
    /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U admin -d postgres -e -c 'CREATE DATABASE watsonx'
    ```
  3. create the `watsonx.demo.events` table, populate with data and run a sample query.
    ```
    cd ./data

    /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U admin -d watsonx -e -f client\ demo-create\ events\ table.sql
    ```
  4. Check that there is data in the table
    ```
    /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U admin -d watsonx -c "SELECT * from demo.events WHERE source_id LIKE 'vsu-%' "
    ```

* Data to be used for hive demonstration is in a CSV file. For analysis in the lakehouse, it is recommended to use data in a large data efficient format like parquet. *duckdb* can be used to import CSV file into a table and then copy the table to a *parquet* format file.
  *duckdb* is not approved for use within IBM, so this conversion was done off IBM resources. However, the commands to perform the conversion are documented below.

  1. start *duckdb* specifying `demo.devices.duckdb` as the file to persist data to.
    ```
    duckdb demo.devices.duckdb
    ```

  2. Create a table in duckdb from the CSV file containing mock data. The `columns` option specifies how *duckdb* should convert CSV text data to data types.
    ```
    CREATE TABLE device_registry AS
      SELECT *
      FROM read_csv(
        'demo.devices.csv',
        header=true,
        columns={
          'id': 'VARCHAR',
          'location_latitude': 'DOUBLE',
          'location_longitude': 'DOUBLE',
          'type': 'VARCHAR',
          'owner': 'VARCHAR',
          'status': 'VARCHAR'});

    SHOW TABLES;

    DESCRIBE device_registry;

    SELECT * FROM device_registry;
    ```

  3. Create a parquet file from the table
    ```
    COPY device_registry_csv TO 'demo.device_registry_csv.parquet' (format parquet);
    ```
  
  4. Quit *duckdb*
    ```
    .quit
    ```

* create demo bucket in minio
  * retrieve minio S3 access key (user name)
    ```
    docker exec ibm-lh-presto printenv | grep LH_S3_ACCESS_KEY | sed 's/.*=//'
    ```
  * Retrieve minio S3 secret key (password)
    ```
    docker exec ibm-lh-presto printenv | grep LH_S3_SECRET_KEY | sed 's/.*=//'
    ```
  * Make sure minio client alias is set up for watsonx docker environment. `mc alias list watsonx-minio` should return as below
    ```
    $ mc alias list watsonx-minio
    watsonx-minio
      URL       : http://localhost:9000
      AccessKey : *<Access key>*
      SecretKey : *<secret key>*
      API       : s3v4
      Path      : auto
    ```
    If it is not set correctly, then create the alias with
    ```
    mc alias set watsonx-minio http://localhost:9000 *<Access key>* *<secret key>*
    ```
  * Create the `demo` bucket
    ```
    mc mb watsonx-minio/demo
    ```
    Check that the bucket has been created
    ```
    mc ls watsonx-minio
    ```
  * Copy `demo.device_registry_csv.parquet` file to the `demo bucket` under a folder called `devices`
    ```
    mc cp data/demo.device_registry_csv.parquet watsonx-minio/demo/devices/device_registry.parquet

    mc ls watsonx-minio/demo/devices
    ```

### Demonstration
* Explore *watsonx.data* lakehouse console
  1. open *watsonx.data* [console](https://localhost:9443). It may be necessary to accept the unsafe location.
  2. login in with user `ibmlhadmin` and password `password`

* Explore *postgreSQL* to view the device events data
  * Get the *PostgreSQL* server password with this command `docker exec ibm-lh-postgres printenv | grep POSTGRES_PASSWORD | sed 's/.*=//'`
  * run select query on `watsonx.demo.events`
      ```
      PGPASSWORD=*<Password from step previous step>* && /opt/homebrew/opt/libpq/bin/psql -h localhost -p 5432 -U admin -d watsonx -c "SELECT * from demo.events WHERE source_id LIKE 'vtu-%'"
      ```
  * point out data from many devices over time. For demo purposes, there is only temperature data, but schema can accommodate data of infinite types from infinite sources.
  * data scientist want to apply machine learning models against this data. We can make this data accessible through the *watsonx.data* lake-house for analysis.

* Add *postgreSQL* catalogue to *watsonx.data* lake-house
  1. First we need to discover important information about the *PostgreSQL* installation
    1. open a command terminal
    2. To retrieve the postgreSQL admin user password, enter `docker exec ibm-lh-postgres printenv | grep POSTGRES_PASSWORD | sed 's/.*=//'` 
        *Note:* The password should have been set to the environment variable `PGPASSWORD` in the demo preparation step.

  2. Add the *PostgreSQL* database to the lake-house
    1. Select the *Infrastructure Manager*
    2. Click *Add Component*, select *Add Database*
    3. In the *Add Database* dialogue enter the following
       *  Database type: ***PostgreSQL*** (it can be found under the From Others section)
       *  Database name: ***watsonx***
       *  Display name: ***PostgreSQLDB***
       *  Hostname: ***ibm-lh-postgres***
       *  Port: ***5432***
       *  Username: ***admin***
       *  Password: ***<Password from step 2>***
       *  Catalog name: ***pgcatalog***

  3. Create association from the `pgcatalog` to the `presto` engine. Select *Save and restart engine*.
  3. Select *Data Manager* from the left-side menu
  4. Expand *pgcatalog*
  5. Show events table information, including schema
  6. Show sample table data for events table.
  7. We now have a copy of the *demo.events* data that can be analysed without impacting production performance. This was created with the open source Presto engine.
      
      In reality, an enterprise would create a schema that is a combination of data from different data sources, which may be different technologies.
      
      For example, device data may come from an object store.

* Explore object store, *minio*
  1. open minio console and show the buckets including the `demo` bucket with the parquet file of devices. Can also show the CSV source for this file in an IDE.

* Add a hive catalog called `demo_data` to view the device data from minio.
  1. Use watsonx.data cosole, *Infrastructure manager* panel, to add a new object storage location connected to the `demo` bucket. Associate the new storage with an Apache Hive catalogue called `demo_data`.
  In the *Add storage* dialogue enter the following
       *  Database type: ***MinIO*** (it can be found under the From Others section)
       *  Bucket name: ***demo***
       *  Display name: ***demo***
       *  Endpoint: ***http://ibm-lh-minio:9000***
       *  Acccess Key: ***<Access key>***
       *  Secret key: ***<Secret key>***
       *  Associated catalog type: ***Apache Hive***
       *  Catalog name: ***demo_data***

  1. Connect the `demo_data` catalog to the `presto` engine.

  2. Start the presto CLI
      ```
      ~/dev/watsonx.data/ibm-lh-dev/bin/presto-cli
      ```

  3. Create a schema called `devices` in the `demo_data` catalogue. The schema will be physicall located in the object storage demo bucket This is where the device registry table will exist.
      ```
      create schema if not exists demo_data.devices
        with (location='s3a://demo/devices');

      show schemas in demo_data;
      ```
    
  4. Create a table in presto based on the device registry
      ```
      CREATE TABLE
        demo_data.devices.device_registry (
          id varchar,
          location_latitude double,
          location_longitude double,
          type varchar,
          owner varchar,
          status varchar)
        WITH (
          format = 'PARQUET',
          external_location='s3a://demo/devices/');

      DESCRIBE demo_data.devices.device_registry;

      SELECT * FROM demo_data.devices.device_registry;
      ```
* Query across data sources
  1. Now a user can do a federated search across data from heterogenous datastores (a postgreSQL data engine for events and device information from a parquet file) to show all events from a particular device, who owns the device and the device status.
      ```
      SELECT device.id AS device_id,
          event.timestamp AS timestamp,
          event.data AS data,
          event.data_point AS data_point,
          device.owner AS device_owner,
          device.status AS device_status
        FROM pgcatalog.demo.events AS event,
          demo_data.devices.device_registry AS device
        WHERE event.source_id = device.id
          AND device.id = 'vcu-0010'
        ORDER BY event.timestamp;
      ```
      This can be used to create another table in the lake-house (using the Create Table As Select, CTAS, pattern). This can be further analysed or used as input to machine learning models for AI use cases.
* Move data to a new table 
  1. so far we have worked with Hive catalog for data ingest and exploration. Iceberg is a more advanced catalog table format which has additional capabilities like:
    * atomic transactions - we can write to the table
    * time machine - generates table snapshots that we can roll back to or query
    * schema alterations - as the data changes, we can alter the schema by adding / removal columns.
  2. Create `events` schema in the `iceberg_data` catalog
  2. we use *CTAS* (Create Table As Select) type of SQL query to create a new table the iceberg catalog based on a `SELECT` query. Either in *Presto CLI* or console SQL tab, enter the following SQL:
    ```
    CREATE TABLE "iceberg_data"."events"."device_events"
      AS SELECT device.id AS device_id,
        event.timestamp AS timestamp,
        event.data AS data,
        event.data_point AS data_point,
        device.owner AS device_owner,
        device.status AS device_status
      FROM pgcatalog.demo.events AS event,
        demo_data.devices.device_registry AS device
      ORDER BY event.timestamp;
    ```
  3. Show device_events table *Time Travel*
  4. Insert data
  5. Select the data to show it's inserted
  6. Roll back
  7. Select the data to show it's no longer there


## Client "call to action"
Clients can start with the developer edition of watsonx.data. This can be run locally using container images and is used in this demonstration.

Start with a PoC using the developer edition to test analysis use cases with large datasets. Engage IBM to identify suitable use cases and let IBM help you successfully implement a data lake house to solve your large data analytic problems.

## Notes
### Running watsonx.data developer edition locally
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
#### Reset the local environment
1. Change directory to *watsonx.data Developer Edition* root directory.
2. Configure the environment variables. The setup instructions will have guided you to create a file to initialise environment variable. `source setenv.sh`
3. Stop the container images
    ```
    $LH_ROOT_DIR/ibm-lh-dev/bin/stop
    ```
4. Delete, or rename the local storage directory `$LH_ROOT_DIR/ibm-lh-dev/localstorage/`
5. Set up the runtime. This step will also create the `localstorage` directory if it was deleted.
    ```
    $LH_ROOT_DIR/ibm-lh-dev/bin/setup --license_acceptance=y --runtime=$DOCKER_EXE
    ```
6. Start the containers
    ```
    $LH_ROOT_DIR/ibm-lh-dev/bin/start
    ```
    This will take a few minutes to complete.
7. Open the *[watsonx.data console](https://localhost:9443/)* console to test the running conainers.

### Testing DB2 locally
**Not successful**

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
Demo data is created using mockaroo.

#### Device events
* mockaroo schema : `data/demo.events.schema.json`

Creates data in CSV format. The data simulates temperature reading events from devices. Devices are identified via the `source_id` column. The `source_id` column should be a foreign key to the devices data.

#### Devices
* mockaroo schema : `data/demo.devices.schema.json`

Creates data in CSV or JSON format. The data simulates a registry of devices keyed by `id` which is a foreign key to `source_id` in the `events` data.

## Useful resources
* Demo consoles
  * [watsonx.data console](https://localhost:9443/)
  * [minio console](http://localhost:9001)
* S/W guidance
  * [watsonx.data documentation](https://www.ibm.com/docs/en/watsonx/watsonxdata)
  * [watsonx.data ingest data from object storage](https://www.ibm.com/docs/en/watsonx/watsonxdata/1.1.x?topic=SSDZ38_1.1.x/lh-console/topics/manual_ingest.htm)
  * [minio client](https://min.io/docs/minio/macos)
    * install with `brew install minio-mc`
  * [duckdb data import](https://duckdb.org/docs/data/overview)
  * [duckdb export to parquet](https://duckdb.org/docs/guides/file_formats/parquet_export)
  * [Presto iceberb connector](https://prestodb.io/docs/current/connector/iceberg.html)
  * [SQL data types](https://www.w3schools.com/sql/sql_datatypes.asp)
  * [mockaroo for creating mock datasets](https://www.mockaroo.com/)

