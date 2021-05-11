# BitDefender scanner repack

Build `deb`, `rpm` and `apk` packages for BitDefender command line virus scanner.

## Build with [Docker](https://www.docker.com)

Build packages for `x64` architecture:

    $ docker-compose up -d

Build packages for `x86` architecture:

    $ BDSCAN_ARCH=i386 docker-compose up -d

*Setting and using variable within same command line in `Windows`:*

    $ cmd /C "set BDSCAN_ARCH=i386&& docker-compose up -d"

### Notes

- View the build logs: `docker-compose logs`
- Shutdown the Docker containers: `docker-compose down`
