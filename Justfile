
# deploy

run:
	npx serve deploy

serve-https:
	cd deploy && openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes -subj "/C=US/ST=CA/L=SF/O=Dev/CN=localhost" && npx serve . --ssl-cert server.crt --ssl-key server.key --listen tcp://0.0.0.0:5000

# cd /Users/jason/dev/workshop/Packages/blueprints/deploy && python3 -m http.   8000server
