# dnsmasq-reverse-proxy-s6 Docker image

dnsmasq, caddy, and s6 (docker-mods) in a single docker container. dnsmasq is configurable via a [simple web UI](https://github.com/jpillora/webproc)

### Forked

Originally this was a fork of [jpillora's dnsmasq](https://github.com/jpillora/docker-dnsmasq).

I just wanted a version of it for ARM. His is only for AMD64 ([Docker Hub](https://hub.docker.com/r/jpillora/dnsmasq)). I also updated webproc to 0.4.0.

This has turned into something more, as I added a reverse proxy and S6 (docker mods).

My: [Docker Hub](https://hub.docker.com/r/zorbatherainy/dnsmasq) & [GitHub](https://github.com/zorbaTheRainy/docker-dnsmasq)

## Why? Doesn't this break the "Docker Way"?

One of the oft-repeated Docker mantras is "one process per container". Generally I agree, but docker-mod/s6-overlay breaks that and there are times when breaking the Docker Way is the Correct Way.

What I needed was a local/split DNS, a reverse proxy, and (occasionally) a Tailscale instance.

The official way to do this was to create a stack with 3 docker images ([dnsmasq](https://github.com/jpillora/docker-dnsmasq), [caddy](https://github.com/caddyserver/caddy-docker), and [tailscale](https://github.com/tailscale/tailscale)), then compress the networking namespace in Docker so that they all shared the same network address and ports. See, the Tailscale documentation on how to do this ([text](https://tailscale.com/kb/1282/docker), [YouTube](https://www.youtube.com/watch?v=YTjYXii4WzI&embeds_referring_euri=https%3A%2F%2Ftailscale.com%2F&source_ve_path=OTY3MTQ)).

The problem is ... this is incredibly fragile.

Restarting one of the containers would leave the other two disconnected from the networking namespace and unresponsive. To make changes, you have to either (1) exec into the container and manually reload dnsmasq/caddy, or (2) update the whole stack. Often, I would remember this when my local/split DNS or reverse proxy would stop working, after I restarted only one of the containers.

I wanted a single image to handle all 3 services. I need to be able to disable each service (on container start-up) for cases where I do not want all three services.

Now, the "stack" of services is much more stable. Everything that needs to share a networking namespace does so automatically.

* dnsmasq & caddy are built into the Docker image
* Tailscale can be added as a docker mod ([blog post](https://tailscale.dev/blog/docker-mod-tailscale), [GitHub](https://github.com/tailscale-dev/docker-mod)).

I assume at some point I may add versions with other DNS and reverse proxies aside from Caddy.

While it is tempting to add in other services (like GoAccess) that I commonly add in the DNS-reverse proxy stack, those services do NOT need (or benefit from) a shared networking namespace. So, I do not think it is the Correct Way to break the Docker Way with them.

Ultimately, the motivation was to put DNS & the reverse proxy into a single Tailscale machine (without a full VM).

## Usage

I will show the usage piece by piece, and then, at the end, put it all together.

Remember ENV variables, mounting points, and all the usual stuff for the containers work the same as if the services where in their own containers. The difference is you put them all in one service command.

### dnsmasq & webproc

1. Create a [`/etc/dnsmasq.conf`](http://oss.segetech.com/intra/srv/dnsmasq.conf) file on the Docker host.

``` ini
#dnsmasq config, for a complete example, see:
#  http://oss.segetech.com/intra/srv/dnsmasq.conf
#log all dns queries
log-queries
#dont use hosts nameservers
no-resolv
#use cloudflare as default nameservers, prefer 1^4
server=1.0.0.1
server=1.1.1.1
strict-order
#serve all .company queries using a specific nameserver
server=/company/10.0.0.1
#explicitly define host-ip mappings
address=/myhost.company/10.0.0.2
```

2. Run the container

```
version: '2.4'

services:
  dnsmasq:
    image: zorbatherainy/dnsmasq
    container_name: dnsmasq
    hostname: dnsmasq
    volumes:
      - /docker/dnsmasq//dnsmasq.conf:/etc/dnsmasq.conf
      - /etc/localtime:/etc/localtime:ro
    # environment:
     #  HTTP_USER: foo
     #  HTTP_PASS: bar
    cap_add:
      - NET_ADMIN
      - NET_RAW
    ports:
      - 53:53/udp
      - 5380:8080
    logging:
      options:
        max-size: "2048m"
    restart: always
```

3. Visit `http://<docker-host>:5380`, authenticate with `foo/bar` and you should see
<img width="833" alt="screen shot 2017-10-15 at 1 41 21 am" src="https://user-images.githubusercontent.com/633843/31580966-baacba62-b1a9-11e7-8439-ca1ddfe828dd.png">
4. Test it out with

```
$ host myhost.company <docker-host>
Using domain server:
Name: <docker-host>
Address: <docker-host>#53
Aliases:

myhost.company has address 10.0.0.2
```

### caddy

1. Create a [`/etc/caddy/Caddyfile`](https://caddyserver.com/docs/caddyfile) file on the Docker host.
2. Go to [Download Caddy](https://caddyserver.com/download) and create whatever non-vanilla version of `caddy` you wish to use. Save it to the host.
3. Run the container

```
services:
  caddy:
    image: caddy:2.8.4
    container_name: caddy
    hostname: reverse_proxy
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    ports:
      - "80:80"
      - "443:443"
    environment:
      - TZ=Europe/Berlin
      # - CADDY_ADMIN=192.168.1.123:2019
    volumes:
      - /etc/localtime:/etc/localtime:ro  # sync to host time
      # enable tailscale 
        # to enable *.ts certs and resolution
        # assume *.sock is on the host or exposed from a tailscale container
      - /run/tailscale/tailscaled.sock:/run/tailscale/tailscaled.sock
      # config files
        # from https://caddyserver.com/download
      - ${DIR_ROOT}/caddy/caddy_linux_custom:/usr/bin/caddy
      - ${DIR_ROOT}/caddy/Caddyfile:/etc/caddy/Caddyfile
      # directories
      - ${DIR_ROOT}/caddy/config:/config
      - ${DIR_ROOT}/caddy/data:/data
      - ${DIR_ROOT}/caddy/logs:/logs
      - ${DIR_ROOT}/caddy/site:/srv
    networks:
      caddy_network:
```

### Tailscale docker-mod

The Docker mod exposes a bunch of environment variables that you can
use to configure it.

| Environment Variable | Description | Example |
| :------------------- | :---------- | :------ |
| `DOCKER_MODS` | The list of additional mods to layer on top of the running container, separated by pipes. | `ghcr.io/tailscale-dev/docker-mod:main` |
| `TAILSCALE_STATE_DIR` | The directory where the Tailscale state will be stored, this should be pointed to a Docker volume. If it is not, then the node will set itself as ephemeral, making the node disappear from your tailnet when the container exits. | `/var/lib/tailscale` |
| `TAILSCALE_AUTHKEY` | The authkey for your tailnet. You can create one in the [admin panel](https://login.tailscale.com/admin/settings/keys). See [here](https://tailscale.com/kb/1085/auth-keys/) for more information about authkeys and what you can do with them. | `tskey-auth-hunter2CNTRL-hunter2hunter2` |
| `TAILSCALE_HOSTNAME` | The hostname that you want to set for the container. If you don't set this, the hostname of the node on your tailnet will be a bunch of random hexadecimal numbers, which many humans find hard to remember. | `wiki` |
| `TAILSCALE_USE_SSH` | Set this to `1` to enable SSH access to the container. | `1` |
| `TAILSCALE_SERVE_PORT` | The port number that you want to expose on your tailnet. This will be the port of your DokuWiki, Transmission, or other container. | `80` |
| `TAILSCALE_SERVE_MODE` | The mode you want to run Tailscale serving in. This should be `https` in most cases, but there may be times when you need to enable `tls-terminated-tcp` to deal with some weird edge cases like HTTP long-poll connections. See [here](https://tailscale.com/kb/1242/tailscale-serve/) for more information. | `https` |
| `TAILSCALE_FUNNEL` | Set this to `true`, `1`, or `t` to enable [funnel](https://tailscale.com/kb/1243/funnel/). For more information about the accepted syntax, please read the [strconv.ParseBool documentation](https://pkg.go.dev/strconv#ParseBool) in the Go standard library. | `on` |
| `TAILSCALE_LOGIN_SERVER` | Set this value if you are using a custom login/control server (Such as headscale) | `https://headscale.example.com` |

Something important to keep in mind is that you really should set up a
separate volume for Tailscale state. Here is how to do that with the
docker commandline:

``` sh
docker volume create dokuwiki-tailscale
```

Then you can mount it into a container by using the volume name
instead of a host path:

``` bash
docker run \
  ... \
  -v dokuwiki-tailscale:/var/lib/tailscale \
  ...
```

### All together as one container

1. Create a [`/etc/dnsmasq.conf`](http://oss.segetech.com/intra/srv/dnsmasq.conf) file on the Docker host.
2. Create a [`/etc/caddy/Caddyfile`](https://caddyserver.com/docs/caddyfile) file on the Docker host.
3. Go to [Download Caddy](https://caddyserver.com/download) and create whatever non-vanilla version of `caddy` you wish to use. Save it to the host.
4. Remember to include the ENV variables to enable/disable the services.

| Environment Variable | Description | Default |
| :------------------- | :---------- | :------ |
| ENABLE_DNS | Runs dnsmasq & webproc | true |
| ENABLE_CADDY | Runs caddy | true |

Tailscale docker-mod is enabled (or not via the [docker-mod mechanism](https://github.com/linuxserver/docker-mods))

* `true` values are 1 or 'true' (case insensative).
* `false` values are anything else.

4. Run the container

```
blah
```

## Other stuff

#### DockerHub tags

At the moment, tags on DockerHub track either:

* the Caddy release number upon which this image is built, or
* for test images, the build time (UTC).

I assume as I tinker with this more the tags will change.

#### MIT License

See the cited GitHubs for the services added to the contianer for their respective licenses.

But as for the parts I wrote ...

Copyright © 2024 ZorbaTheRainy

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.