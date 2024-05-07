## client demo
### data preparation
Data is in a CSV file. For analysis in the lakehouse, it is recommended to use data in a large data efficient format like parquet. Use *duckdb* to import CSV file into a table and then copy the table to a *parquet* file. *duckdb* is not approved for use within IBM, so this conversion was done off IBM resources. However, the commands to perform the conversion are documented below.
```
< from mac air>
```

### Demo commands
Back on IBM resources...

1. Upload parquet file to object store
    ```
    mc cp data/demo.device_registry_csv.parquet watsonx-minio/demo/devices/device_registry.parquet
    ```

2. Use watsonx.data cosole, *Infrastructure manager* panel, to create a new object storage catalogue called `demo_data` connected to the `demo` bucket. Associate the new storage with an Apache Hive catalogue.

3. Connect the `demo_data` catalog to the `presto` engine.

4. Start `presto-cli`.
    ```
    cd ~/dev/watsonx.data
    ibm-lh-dev/bin/presto-cli
    ```

5. Create a new schema based on the bucket / path of `demo/devices`.
    ```
    create schema if not exists demo_data.devices
      with (location='s3a://demo/devices');

    show schemas;
    ```

6. Create a table in presto based on the device registry
    ```
    create table
      demo_data.devices.device_registry (
        id varchar,
        location_latitude double,
        location_longitude double,
        type varchar,
        owner varchar,
        status varchar)
      with (
        format = 'PARQUET',
        location='s3a://demo/devices/device_registry.parquet');

    describe demo_data.devices.device_registry;

    select * from demo_data.devices.device_registry;
    ```

7. Now can do a federated search across data from heterogenous datastores (a postgreSQL data engine for events and device information from a parquet file) to show all events from a particular device, who owns the device and the device status.
    ```
    SELECT device.id AS device_id,
        event.timestamp AS timestamp,
        event.data AS data,
        event.data_point AS data_point,
        device.owner AS device_owner,
        device.status AS device_status
      FROM demo.demo.events AS event,
        hive_data.devices2.device_registry2 AS device
      WHERE event.source_id = device.id
        AND device.id = 'vcu-0010'
      ORDER BY event.timestamp;
    ```

