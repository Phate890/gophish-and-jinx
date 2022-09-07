#!/usr/bin/env bash

# make our output look nice...
script_name="evilgophish setup"

function check_privs () {
    if [[ "$(whoami)" != root ]]; then
        print_error "You need root privileges to run this script."
        exit 1
    fi
}

function print_good () {
    echo -e "[${script_name}] \x1B[01;32m[+]\x1B[0m $1"
}

function print_error () {
    echo -e "[${script_name}] \x1B[01;31m[-]\x1B[0m $1"
}

function print_warning () {
    echo -e "[${script_name}] \x1B[01;33m[-]\x1B[0m $1"
}

function print_info () {
    echo -e "[${script_name}] \x1B[01;34m[*]\x1B[0m $1"
}

if [[ $# -ne 4 ]]; then
    print_error "Missing Parameters:"
    print_error "Usage:"
    print_error './setup <root domain> <evilginx2 subdomain(s)> <gophish subdomain(s)> <redirect url>'
    print_error " - root domain             - the root domain to be used for the campaign"
    print_error " - evilginx2 subdomains    - a space separated list of evilginx2 subdomains, can be one if only one"
    print_error " - gophish subdomains      - a space separated list of gophish subdomains, can be one if only one"
    print_error " - redirect url            - URL to redirect unauthorized Apache requests"
    print_error "Example:"
    print_error '  ./setup.sh example.com "training login" "download www" https://redirect.com/'

    exit 2
fi

# Set variables from parameters
root_domain="${1}"
evilginx2_subs="${2}"
gophish_subs="${3}"
redirect_url="${4}"
evilginx_dir=$HOME/.evilginx

# Get path to certificates
function get_certs_path () {
    print_info "Run the command below to generate letsencrypt certificates (will need to create two (2) DNS TXT records):"
    print_info "letsencrypt certonly --manual --preferred-challenges=dns --email admin@${root_domain} --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d '*.${root_domain}' -d '${root_domain}'"
    print_info "Once certificates are generated, enter path to certificates:"
    read -r certs_path
    if [[ ${certs_path: -1} != "/" ]]; then
        certs_path+="/"
    fi
}

# Install needed dependencies
function install_depends () {
    print_info "Installing dependencies with apt"
    apt-get update
    apt-get install apache2 build-essential letsencrypt wget git tmux -y > /dev/null
    print_good "Installed dependencies with apt!"
    print_info "Installing Go from source"
    wget https://go.dev/dl/go1.19.linux-amd64.tar.gz > /dev/null
    tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz
    ln -sf /usr/local/go/bin/go /usr/bin/go
    rm go1.19.linux-amd64.tar.gz
    print_good "Installed Go from source!"
}

# Configure Apache
function setup_apache () {
    # Enable needed Apache mods
    print_info "Configuring Apache"
    a2enmod proxy > /dev/null 
    a2enmod proxy_http > /dev/null
    a2enmod proxy_balancer > /dev/null
    a2enmod lbmethod_byrequests > /dev/null
    a2enmod rewrite > /dev/null
    a2enmod ssl > /dev/null

    # Prepare Apache 000-default.conf file
    evilginx2_cstring=""
    for esub in ${evilginx2_subs} ; do
        evilginx2_cstring+=${esub}.${root_domain}
        evilginx2_cstring+=" "
    done
    gophish_cstring=""
    for gsub in ${gophish_subs} ; do
        gophish_cstring+=${gsub}.${root_domain}
        gophish_cstring+=" "
    done
    # Replace template values with user input
    sed "s/ServerAlias evilginx2.template/ServerAlias ${evilginx2_cstring}/g" 000-default.conf.template > 000-default.conf
    sed -i "s/ServerAlias gophish.template/ServerAlias ${gophish_cstring}/g" 000-default.conf
    sed -i "s|SSLCertificateFile|SSLCertificateFile ${certs_path}cert.pem|g" 000-default.conf
    sed -i "s|SSLCertificateChainFile|SSLCertificateChainFile ${certs_path}fullchain.pem|g" 000-default.conf
    sed -i "s|SSLCertificateKeyFile|SSLCertificateKeyFile ${certs_path}privkey.pem|g" 000-default.conf
    # Don't listen on port 80
    sed -i "s|Listen 80||g" /etc/apache2/ports.conf
    # Input redirect information
    sed "s|https://en.wikipedia.org/|${redirect_url}|g" redirect.rules.template > redirect.rules
    # Copy over blacklist file
    cp 000-default.conf /etc/apache2/sites-enabled/
    cp blacklist.conf /etc/apache2/
    chown www-data.www-data /etc/apache2/blacklist.conf
    # Copy over redirect rules file
    cp redirect.rules /etc/apache2/
    rm redirect.rules 000-default.conf
    chown www-data.www-data /etc/apache2/redirect.rules
    print_good "Apache configured!"
}

# Configure and install evilginx2
function setup_evilginx2 () {
    print_info "Configuring evilginx2"
    mkdir -p "${evilginx_dir}/crt/${root_domain}"
    for i in evilginx2/phishlets/*.yaml; do
        phishlet=$(echo "${i}" | awk -F "/" '{print $3}' | sed 's/.yaml//g')
        cp ${certs_path}fullchain.pem "${evilginx_dir}/crt/${root_domain}/${phishlet}.crt"
        cp ${certs_path}privkey.pem "${evilginx_dir}/crt/${root_domain}/${phishlet}.key"
    done
    cd evilginx2 || exit 1
    go build
    cd ..
    print_good "Configured evilginx2!"
}

# Configure and install gophish
function setup_gophish () {
    print_info "Configuring gophish"
    sed "s|\"cert_path\": \"gophish_template.crt\",|\"cert_path\": \"${certs_path}fullchain.pem\",|g" config.json.template > gophish/config.json
    sed -i "s|\"key_path\": \"gophish_template.key\"|\"key_path\": \"${certs_path}privkey.pem\"|g" gophish/config.json
    cd gophish || exit 1
    go build
    cd ..
    print_good "Configured gophish!"
}

function main () {
    check_privs
    install_depends
    get_certs_path
    setup_apache
    setup_evilginx2
    setup_gophish
    print_good "Installation complete! When ready start apache with: systemctl start apache2"
    print_info "It is recommended to run both servers inside a tmux session to avoid losing them over SSH!"
}

main