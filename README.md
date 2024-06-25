# bcit tomcat

## Extended version of the official Tomcat image

This image extends the official Tomcat image by allowing it to pull configuration and WAR resources from local and remote sources.

## Environmental Variables

### BASE_URL (mandatory)

- **Description**: Location of the TGZ or ZIP archive containing `CATALINA_BASE` runtime configuration that needs to be deployed to the container. Supported URL schemes: `file`, `http`, `https`, `s3`.
- **Default value**: None
- **Examples**:
  - `BASE_URL=file:///path/to/file/in/container`
  - `BASE_URL=https://remote-web-server/path/to/file`
  - `BASE_URL=s3://bucket/path/to/object`

### CATALINA_BASE

- **Description**: Location within the container where the Tomcat runtime configuration is deployed.
- **Default value**: /app/tomcat
- **Example**: `CATALINA_BASE=/app/tomcat`

### CONNECT_TIMEOUT

- **Description**: Maximum time in seconds to initiate a remote connection.
- **Default value**: 5
- **Example**: `CONNECT_TIMEOUT=10`

### DEBUG

- **Description**: Enable or disable container debug output.
- **Default value**: 0 (disabled)
- **Example**: `DEBUG=1`

### PROXY

- **Description**: Use the specified proxy. The proxy string can be specified as `[protocol://]host[:port]`.
- **Default value**: None
- **Example**: `PROXY=proxy_server:8080`

### RUN_DOCKERIZE

- **Description**: Generate application configuration files at container startup from templates and container environment variables. It processes all template files with `.tmpl` extension, removing the `.tmpl` suffix from the resulting filenames.
- **Default value**: 0 (disabled)
- **Example**: `RUN_DOCKERIZE=1`

### RUN_POSTDEPLOYMENT

- **Description**: Process all BASH `.sh` scripts in the `CATALINA_BASE/post_deployment/scripts` directory before the Tomcat process starts.
- **Default value**: 0 (disabled)
- **Example**: `RUN_POSTDEPLOYMENT=1`

### RUN_VANILLA

- **Description**: Ignore all environment variables except `TZ` and run the default Tomcat container.
- **Default value**: 0 (disabled)
- **Example**: `RUN_VANILLA=1`

### S3_URL (mandatory for s3://)

- **Description**: Global URL location of the S3 server.
- **Default value**: None
- **Example**: `S3_URL=https://minio-server`

Can be overridden for each indexed `WAR_URL` using indexed `S3_URL`.

- **Example**:

  - `WAR_0_URL=s3://bucket/path/to/object`
  - `S3_0_URL=https://another-minio-server`

### S3_AK (mandatory for s3://)

- **Description**: Global S3 Access Key.
- **Default value**: None
- **Example**: `S3_AK=cAoYZ6O2LCzArSKS`

Can be overridden for each indexed `WAR_URL` using indexed `S3_AK`.

- **Example**:

  - `WAR_0_URL=s3://bucket/path/to/object`
  - `S3_0_AK=A1ozB7O3bAaZpVZ1`

### S3_SK (mandatory for s3://)

- **Description**: Global S3 Secret Key.
- **Default value**: None
- **Example**: `S3_SK=hOqIM1zsMdpRflkQ8kqpYRW05KS3PnPm`

Can be overridden for each indexed `WAR_URL` using indexed `S3_SK`.

- **Example**:

  - `WAR_0_URL=s3://bucket/path/to/object`
  - `S3_0_SK=a22AB4xxnD3wABQk5KQpZZZ31Qs7wMDb`

### WAR_NAME

- **Description**: Name of the WAR file when deployed to the container. Used when the deployed WAR filename needs to be different from the original WAR filename.
- **Default value**: None
- **Example**: `WAR_NAME=SampleApp.war`

### WAR_URL (mandatory)

- **Description**: Location of the WAR file that needs to be deployed to the container. Supported URL schemes: `file`, `http`, `https`, `s3`.
- **Default value**: None
- **Examples**:
  - `WAR_URL=file:///path/to/file/in/container`
  - `WAR_URL=https://remote-web-server/path/to/file`
  - `WAR_URL=s3://bucket/path/to/object`

Multiple WAR files can be deployed simultaneously. Each `WAR_URL` is identified by a unique index number, which refers to its respective indexed `WAR_NAME`.

- **Example**:
  - `WAR_0_URL=s3://bucket/path/to/object`
  - `WAR_0_NAME=NewName.war`
  - `WAR_1_URL=https://remote-web-server/path/to/file1`
  - `WAR_2_URL=https://remote-web-server/path/to/file2`
  - `WAR_2_NAME=DifferentName.war`

### TZ

- **Description**: Set timezone.
- **Default value**: America/Vancouver
- **Example**: `TZ=America/Vancouver`

## Usage

### CATALINA_BASE Archive

A typical `CATALINA_BASE` folder structure contains the following files and directories at a minimum:

```bash
catalina_base/
├── bin
│   └── setenv.sh
├── conf
│   ├── catalina.policy
│   ├── catalina.properties
│   ├── context.xml
│   ├── logging.properties
│   ├── server.xml
│   ├── tomcat-users.xml
│   └── web.xml
└── lib
```

Create your configuration files, use templates if needed, and create a TGZ or ZIP archive of the content within the `catalina_base` folder. Do not include the `catalina_base` directory itself, only its content.

**Example**:

- (Linux): `cd catalina_base; tar -cvzf catalina_base.tgz *`
- (MacOS): `cd catalina_base; COPYFILE_DISABLE=1 tar --no-xattrs -cvzf catalina_base.tgz *`

To test the content of the TGZ archive, run `tar -tf catalina_base.tgz`.

**Example**:

```bash
$ tar -tf catalina_base.tgz
bin/
bin/setenv.sh
conf/
conf/logging.properties
conf/catalina.properties
conf/server.xml
conf/tomcat-users.xml
conf/context.xml
conf/catalina.policy
conf/web.xml
lib/
```

### Docker Compose

The following is an example of a possible Docker Compose configuration:

```yaml
services:
  ## Tomcat Extended
  tomcat-extended:
    container_name: tomcat-extended
    image: bcit.io/tomcat:[version]
    user: "10001:10001"
    environment:
      - BASE_URL=https://remote-web-server/path/to/catalina_base.tgz
      - S3_AK=ACCESSKEY
      - S3_SK=SECRETKEY
      - S3_URL=https://minio-server
      - WAR_0_URL=https://remote-web-server/path/to/ROOT.war
      - WAR_1_NAME=SampleWebApp.war
      - WAR_1_URL=s3://bucket/path/to/SampleWebApp_v15.5.32.war
    ports:
      - 8080:8080
```

### Podman usage example

`podman run -it --rm --mount=type=bind,source=./resources/,destination=/tmp/tomcat/,z -e BASE_URL=file:///tmp/tomcat/catalina_base.tgz -e WAR_URL=file:///tmp/tomcat/ROOT.war  -p 8080:8080 bcit.io/tomcat:[version]`

### Docker usage example

`docker run -it --rm --mount=type=bind,source=./resources/,destination=/tmp/tomcat/ -e BASE_URL=file:///tmp/tomcat/catalina_base.tgz -e WAR_URL=file:///tmp/tomcat/ROOT.war  -p 8080:8080 bcit.io/tomcat:[version]`
