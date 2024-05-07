## client demo preparation
Use watsonx.data cosole, *Infrastructure manager* panel, to create a new catalog called `demo_data` associated with the `demo` bucket.

Connect the `demo_data` catalog to the `presto` engine.

Start `presto-cli` using the `demo_data` catalog.

Create a new schema based on the bucket / path of `demo/devices`.
```
./presto-cli --catalog demo_data

create schema if not exists demo_data.devices
  with (location='s3a://demo/devices');

show schemas;

create table demo_data.devices.device_registry (id varchar, location_latitude varchar, location_longitude varchar, type varchar, owner varchar, status varchar) with (format = 'CSV', external_location='s3a://demo/devices', skip_header_line_count=1);

select * from demo_data.devices.device_registry;

use demo;

show tables;
```

## Try next
Make another bucket for demo with iceberg catalog to allow richer data ingest.

Create new bucket called `demo_iceberg_bucket`

Copy `demo.devices.csv` to `demo_iceberg_bucket/devices`

Register the bucket in *Infrastructure Manager* with catalog name `demo_iceberg`

Use modified commands above to ceate schema and ingest data.

* hypothesis
  * data types are preserved
  * csv header line is not ingested
* risk
  * may need to convert CSV to iceberg table format. Examples for presto iceberg connector only shows *ORC* format. https://www.ibm.com/docs/en/watsonx/watsonxdata/1.0.x?topic=data-ingesting-from-object-storage-bucket
  * creating from hive data where all data types are VARCHAR means that we still do not get datatypes in the iceberg format. However we can alter the schema, so that may help.
  

## create table in iceberg_data catalog ON paquet file in object store  
Data is in a CSV file. Use *duckdb* to import CSV file into a table and then copy the table to a *parquet* file.
```
< from mac air>
```


Upload parquet file to object store
```
mc cp data/demo.device_registry_csv.parquet watsonx-minio/iceberg-bucket/devices/device_registry.parquet
```

Create schema in `iceberg_data` catalog connected to object store bucket folder
```
create schema if not exists iceberg_data.devices with (location='s3a://iceberg-bucket/devices');
show schemas in iceberg_data;
```

Create table in catalog schema on parquet file in object store
```
create table iceberg_data.devices.device_registry (id varchar, location_latitude double, location_longitude double, type varchar, owner varchar, status varchar) with (format = 'PARQUET', location='s3a://iceberg-bucket/devices/device_registry.parquet');

describe iceberg_data.devices.device_registry;

select * from iceberg_data.devices.device_registry;
```

