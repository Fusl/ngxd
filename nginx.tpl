user www-data;
worker_processes auto;
pid /run/nginx.pid;
events {
	worker_connections 1024;
	multi_accept on;
}
http {
	sendfile off;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	server_tokens off;
	server_names_hash_bucket_size 64;
	server_name_in_redirect off;
	default_type application/octet-stream;
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_prefer_server_ciphers on;
	access_log /dev/null;
	error_log /dev/null;
	gzip on;
	gzip_disable "msie6";
	# proxy_cache_background_update off;
	proxy_cache_bypass $http_authorization;
	proxy_cache_convert_head on;
	proxy_cache_key $scheme$host$request_uri;
	# proxy_cache_key $scheme$proxy_host$request_uri;
	proxy_cache_lock off;
	proxy_cache_lock_age 5s;
	# proxy_cache_max_range_offset
	proxy_cache_methods GET HEAD;
	proxy_cache_min_uses 1;
	proxy_cache_path /var/lib/nginx/body/cache levels=1:2 keys_zone=nginxcache:16m inactive=1h max_size=5g;
	# proxy_cache_purge
	proxy_cache_revalidate off;
	proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_503 http_504;
	proxy_cache_valid 200 301 302 304 1h;
	proxy_cache_valid 404 1m;
	proxy_no_cache $http_authorization;
	proxy_ignore_headers X-Accel-Expires Expires Cache-Control;
	server {
		{{~dot.config.listen :listenip}}
			listen {{=listenip}}:80 default_server;
		{{~}}
		server_name filter.httpfilter.meo.ws;
		return 200 '';
		add_header Content-Type 'text/plain';
	}
	server {
		{{~dot.config.listen :listenip}}
			listen {{=listenip}}:443 default_server ssl http2;
		{{~}}
		server_name filter.httpfilter.meo.ws;
		return 200 '';
		add_header Content-Type 'text/plain';
		ssl_certificate /etc/nginx/ssl/_/crt;
		ssl_certificate_key /etc/nginx/ssl/_/key;
		ssl_prefer_server_ciphers on;
		ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
		ssl_ciphers 'EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA256:EECDH:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!IDEA:!ECDSA:kEDH:CAMELLIA128-SHA:AES128-SHA';
		ssl_dhparam /etc/nginx/ssl/dhparam.pem;
	}
	{{~Object.keys(dot.upstreams) :upstreamid}}
		upstream {{=dot.exec('require', 'md5')(upstreamid)}} {
			keepalive 300;
			hash $remote_addr consistent;
			{{~dot.upstreams[upstreamid].hosts :hostip}}
				server {{=hostip}};
			{{~}}
		}
	{{~}}
	{{~Object.keys(dot.vhosts) :vhostid}}
		server {
			{{~dot.config.listen :listenip}}
				listen {{=listenip}}:80;
			{{~}}
			server_name {{=vhostid}} www.{{=vhostid}};
			location = /cdn-cgi/trace {
				add_header Content-Type 'text/plain';
				return 200 'args=$args\nconnection=$connection\nconnection_requests=$connection_requests\ncontent_length=$content_length\ncontent_type=$content_type\nhost=$host\nhostname=$hostname\nhttp2=$http2\nhttps=$https\nis_args=$is_args\nmsec=$msec\npid=$pid\nremote_addr=$remote_addr\nremote_port=$remote_port\nrequest=$request\nrequest_length=$request_length\nrequest_method=$request_method\nrequest_time=$request_time\nrequest_uri=$request_uri\nscheme=$scheme\nserver_protocol=$server_protocol\ntime_iso8601=$time_iso8601\n';
			}
			{{?typeof dot.vhosts[vhostid] === 'object' && dot.vhosts[vhostid].redirect}}
				location / {
					return 301 {{=dot.vhosts[vhostid].redirect}};
				}
			{{??typeof dot.vhosts[vhostid] === 'object' && dot.vhosts[vhostid].forcessl}}
				location / {
					return 301 https://$http_host$request_uri;
				}
			{{??}}
				location ~* \.(bmp|class|css|csv|doc|docx|ejs|eot|eps|gif|ico|jar|jpeg|jpg|js|mid|midi|otf|pdf|pict|pls|png|ppt|pptx|ps|svg|svgz|swf|tif|tiff|ttf|webp|woff|woff2|xls|xlsx)$ {
					proxy_cache nginxcache;
					expires 1h;
					add_header X-Proxy-Cache $upstream_cache_status;
					add_header Pragma "public";
					add_header Cache-Control "public, max-age=3600";
					{{?typeof dot.vhosts[vhostid] === 'string' && dot.upstreams[dot.vhosts[vhostid]]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid]].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid])}};
					{{??typeof dot.vhosts[vhostid] === 'object' && dot.upstreams[dot.vhosts[vhostid].target]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid].target].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid].target)}};
					{{??typeof dot.vhosts[vhostid] === 'string'}}
						proxy_pass {{=dot.vhosts[vhostid]}};
					{{??}}
						proxy_pass {{=dot.vhosts[vhostid].target}};
					{{?}}
					{{?typeof dot.vhosts[vhostid] !== 'object' || typeof dot.vhosts[vhostid].reqheaders !== 'object' || Object.keys(dot.vhosts[vhostid].reqheaders).map(Function.prototype.call, String.prototype.toLowerCase).indexOf('host') === -1}}
						proxy_set_header Host $http_host;
					{{?}}
					proxy_set_header X-Real-Ip $remote_addr;
					proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
					proxy_set_header X-Forwarded-Proto $scheme;
					proxy_set_header X-Secure-Request 'false';
					proxy_set_header Upgrade $http_upgrade;
					proxy_set_header Connection "upgrade";
					{{?typeof dot.vhosts[vhostid] === 'object' && typeof dot.vhosts[vhostid].reqheaders === 'object'}}
						{{~Object.keys(dot.vhosts[vhostid].reqheaders) :reqheader}}
							proxy_set_header {{=reqheader}} '{{=dot.vhosts[vhostid].reqheaders[reqheader]}}';
						{{~}}
					{{?}}
					proxy_http_version 1.1;
					proxy_buffering on;
				}
				location / {
					{{?typeof dot.vhosts[vhostid] === 'string' && dot.upstreams[dot.vhosts[vhostid]]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid]].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid])}};
					{{??typeof dot.vhosts[vhostid] === 'object' && dot.upstreams[dot.vhosts[vhostid].target]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid].target].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid].target)}};
					{{??typeof dot.vhosts[vhostid] === 'string'}}
						proxy_pass {{=dot.vhosts[vhostid]}};
					{{??}}
						proxy_pass {{=dot.vhosts[vhostid].target}};
					{{?}}
					{{?typeof dot.vhosts[vhostid] !== 'object' || typeof dot.vhosts[vhostid].reqheaders !== 'object' || Object.keys(dot.vhosts[vhostid].reqheaders).map(Function.prototype.call, String.prototype.toLowerCase).indexOf('host') === -1}}
						proxy_set_header Host $http_host;
					{{?}}
					proxy_set_header X-Real-Ip $remote_addr;
					proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
					proxy_set_header X-Forwarded-Proto $scheme;
					proxy_set_header X-Secure-Request 'false';
					proxy_set_header Upgrade $http_upgrade;
					proxy_set_header Connection "upgrade";
					{{?typeof dot.vhosts[vhostid] === 'object' && typeof dot.vhosts[vhostid].reqheaders === 'object'}}
						{{~Object.keys(dot.vhosts[vhostid].reqheaders) :reqheader}}
							proxy_set_header {{=reqheader}} '{{=dot.vhosts[vhostid].reqheaders[reqheader]}}';
						{{~}}
					{{?}}
					proxy_http_version 1.1;
					proxy_buffering off;
				}
			{{?}}
		}
		server {
			{{~dot.config.listen :listenip}}
				listen {{=listenip}}:443 ssl http2;
			{{~}}
			server_name {{=vhostid}} www.{{=vhostid}};
			{{?dot.exec('require', 'fs').existsSync('/root/nginx/ssl/' + vhostid + '/crt')}}
				ssl_certificate /etc/nginx/ssl/{{=vhostid}}/crt;
				ssl_certificate_key /etc/nginx/ssl/{{=vhostid}}/key;
			{{?}}
			location = /cdn-cgi/trace {
				add_header Content-Type 'text/plain';
				return 200 'args=$args\nconnection=$connection\nconnection_requests=$connection_requests\ncontent_length=$content_length\ncontent_type=$content_type\nhost=$host\nhostname=$hostname\nhttp2=$http2\nhttps=$https\nis_args=$is_args\nmsec=$msec\npid=$pid\nremote_addr=$remote_addr\nremote_port=$remote_port\nrequest=$request\nrequest_length=$request_length\nrequest_method=$request_method\nrequest_time=$request_time\nrequest_uri=$request_uri\nscheme=$scheme\nserver_protocol=$server_protocol\ntime_iso8601=$time_iso8601\n';
			}
			{{?typeof dot.vhosts[vhostid] === 'object' && dot.vhosts[vhostid].redirect}}
				return 301 {{=dot.vhosts[vhostid].redirect}};
			{{??}}
				location ~* \.(bmp|class|css|csv|doc|docx|ejs|eot|eps|gif|ico|jar|jpeg|jpg|js|mid|midi|otf|pdf|pict|pls|png|ppt|pptx|ps|svg|svgz|swf|tif|tiff|ttf|webp|woff|woff2|xls|xlsx)$ {
					proxy_cache nginxcache;
					expires 1h;
					add_header X-Proxy-Cache $upstream_cache_status;
					add_header Pragma "public";
					add_header Cache-Control "public, max-age=3600";
					{{?typeof dot.vhosts[vhostid] === 'string' && dot.upstreams[dot.vhosts[vhostid]]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid]].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid])}};
					{{??typeof dot.vhosts[vhostid] === 'object' && dot.upstreams[dot.vhosts[vhostid].target]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid].target].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid].target)}};
					{{??typeof dot.vhosts[vhostid] === 'string'}}
						proxy_pass {{=dot.vhosts[vhostid]}};
					{{??}}
						proxy_pass {{=dot.vhosts[vhostid].target}};
					{{?}}
					{{?typeof dot.vhosts[vhostid] !== 'object' || typeof dot.vhosts[vhostid].reqheaders !== 'object' || Object.keys(dot.vhosts[vhostid].reqheaders).map(Function.prototype.call, String.prototype.toLowerCase).indexOf('host') === -1}}
						proxy_set_header Host $http_host;
					{{?}}
					proxy_set_header X-Real-Ip $remote_addr;
					proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
					proxy_set_header X-Forwarded-Proto $scheme;
					proxy_set_header X-Secure-Request 'true';
					proxy_set_header Upgrade $http_upgrade;
					proxy_set_header Connection "upgrade";
					{{?typeof dot.vhosts[vhostid] === 'object' && typeof dot.vhosts[vhostid].reqheaders === 'object'}}
						{{~Object.keys(dot.vhosts[vhostid].reqheaders) :reqheader}}
							proxy_set_header {{=reqheader}} '{{=dot.vhosts[vhostid].reqheaders[reqheader]}}';
						{{~}}
					{{?}}
					proxy_http_version 1.1;
					proxy_buffering on;
				}
				location / {
					{{?typeof dot.vhosts[vhostid] === 'string' && dot.upstreams[dot.vhosts[vhostid]]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid]].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid])}};
					{{??typeof dot.vhosts[vhostid] === 'object' && dot.upstreams[dot.vhosts[vhostid].target]}}
						proxy_pass {{=dot.upstreams[dot.vhosts[vhostid].target].scheme}}://{{=dot.exec('require', 'md5')(dot.vhosts[vhostid].target)}};
					{{??typeof dot.vhosts[vhostid] === 'string'}}
						proxy_pass {{=dot.vhosts[vhostid]}};
					{{??}}
						proxy_pass {{=dot.vhosts[vhostid].target}};
					{{?}}
					{{?typeof dot.vhosts[vhostid] !== 'object' || typeof dot.vhosts[vhostid].reqheaders !== 'object' || Object.keys(dot.vhosts[vhostid].reqheaders).map(Function.prototype.call, String.prototype.toLowerCase).indexOf('host') === -1}}
						proxy_set_header Host $http_host;
					{{?}}
					proxy_set_header X-Real-Ip $remote_addr;
					proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
					proxy_set_header X-Forwarded-Proto $scheme;
					proxy_set_header X-Secure-Request 'true';
					proxy_set_header Upgrade $http_upgrade;
					proxy_set_header Connection "upgrade";
					{{?typeof dot.vhosts[vhostid] === 'object' && typeof dot.vhosts[vhostid].reqheaders === 'object'}}
						{{~Object.keys(dot.vhosts[vhostid].reqheaders) :reqheader}}
							proxy_set_header {{=reqheader}} '{{=dot.vhosts[vhostid].reqheaders[reqheader]}}';
						{{~}}
					{{?}}
					proxy_http_version 1.1;
					proxy_buffering off;
				}
			{{?}}
		}
	{{~}}
}
