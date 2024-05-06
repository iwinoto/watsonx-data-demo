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
  

  


