# docker-dnsmasq

dnsmasq in a docker container, configurable via a [simple web UI](https://github.com/jpillora/webproc)


## Forked

This is a fork of [jpillora's dnsmasq](https://github.com/jpillora/docker-dnsmasq).

I just wanted a verison of it for ARM.  His is only for AMD64 ([Docker Hub](https://hub.docker.com/r/jpillora/dnsmasq)).

I also updated webproc to 0.4.0.

[Docker Hub](https://hub.docker.com/r/zorbatherainy/dnsmasq) & [GitHub](https://github.com/zorbaTheRainy/docker-dnsmasq)


### Usage

1. Create a [`/opt/dnsmasq.conf`](http://oss.segetech.com/intra/srv/dnsmasq.conf) file on the Docker host

   ```ini
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

1. Run the container

   ```
   $ docker run \
   	--name dnsmasq \
   	-d \
   	-p 53:53/udp \
   	-p 5380:8080 \
   	-v /opt/dnsmasq.conf:/etc/dnsmasq.conf \
   	--log-opt "max-size=100m" \
   	-e "HTTP_USER=foo" \
   	-e "HTTP_PASS=bar" \
   	--restart always \
   	zorbatherainy/dnsmasq
   ```

   or
   
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

1. Visit `http://<docker-host>:5380`, authenticate with `foo/bar` and you should see

   <img width="833" alt="screen shot 2017-10-15 at 1 41 21 am" src="https://user-images.githubusercontent.com/633843/31580966-baacba62-b1a9-11e7-8439-ca1ddfe828dd.png">

1. Test it out with

   ```
   $ host myhost.company <docker-host>
   Using domain server:
   Name: <docker-host>
   Address: <docker-host>#53
   Aliases:

   myhost.company has address 10.0.0.2
   ```

#### MIT License

Copyright &copy; 2024 ZorbaTheRainy

Copyright &copy; 2018 Jaime Pillora &lt;dev@jpillora.com&gt;

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

[dockerhub]: https://hub.docker.com/r/zorbatherainy/dnsmasq/
