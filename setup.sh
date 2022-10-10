#!/usr/bin/env bash

JOIN_WAIT=3
BASE_URI="https://api.zerotier.com/api/v1"
TMP_OUTPUT="/tmp/member.json"

OUTPUT_RED=$(tput setaf 1)
OUTPUT_YELLOW=$(tput setaf 3)
OUTPUT_BOLD=$(tput bold)
OUTPUT_CLEAR=$(tput sgr 0)

function log {
    echo -e "\n${1//?/*}**"
    echo -e "* ${OUTPUT_YELLOW}$1${OUTPUT_CLEAR}\n*"
}

function error {
    echo -e "\n${1//?/*}**"
    echo -e "* ${OUTPUT_RED}$1${OUTPUT_CLEAR}\n*"
}

if [[ -z "$1" ]]; then
    error "No action specified!"
    exit 1
fi
ACTION=${1}

if [[ "$ACTION" == "install" && -z "$2" ]]; then
    error "No Network specified - go to: https://my.zerotier.com/network and create create/copy Network ID"
    exit 1
fi
NETWORK=${2}

if [[ "$ACTION" == "install" && -z "$3" ]]; then
    error "No API token! - go to: https://my.zerotier.com/account and create token"
    exit 1
fi
TOKEN=${3}

case "${ACTION}" in
    "install")
        if [[ ! $(command -v zerotier-cli) ]]; then
            log "Installing ZeroTier..."
            curl -s https://install.zerotier.com | sudo bash

            if [[ ! $(command -v zerotier-cli) ]]; then
                error "ZeroTier not installed properly?"
                exit 1
            fi
        fi

        ZEROTIER_ID=$(sudo zerotier-cli info | cut -d ' ' -f 3)
        log "Host ID: ${ZEROTIER_ID}"

        log "Joining network: ${OUTPUT_CLEAR} ${OUTPUT_BOLD}${NETWORK}"
        zerotier-cli join ${NETWORK}

        log "Giving ZeroTier a chance to register host properly by waiting ${JOIN_WAIT} seconds"
        sleep ${JOIN_WAIT}

        log "Getting actual host: ${ZEROTIER_ID} status for Network: ${NETWORK}"
        cmd="curl -s -N -X GET \
            ${BASE_URI}/network/${NETWORK}/member/${ZEROTIER_ID} \
            -H 'authorization: bearer ${TOKEN}' \
            -H 'cache-control: no-cache' \
            -H 'content-type: application/json' \
            -o ${TMP_OUTPUT}"
        eval $cmd

        log "Authorizing host: ${ZEROTIER_ID} on Network: ${NETWORK} "
        sed -i 's/"authorized":false/"authorized":true/' ${TMP_OUTPUT}

        MEMBER=$(cat ${TMP_OUTPUT})
        cmd="curl -s -N -X POST \
            ${BASE_URI}/network/${NETWORK}/member/${ZEROTIER_ID} \
            -H 'authorization: bearer ${TOKEN}' \
            -H 'cache-control: no-cache' \
            -H 'content-type: application/json' \
            -d '${MEMBER}' \
            -o /dev/null"
        eval $cmd

        log "Done!"
    ;;

    "uninstall")
        log "Uninstalling ZeroTier and clearing all data!"
        sudo apt remove -y zerotier*
        rm -rf /var/lib/zerotier*
    ;;

    *)
        log "Action not supported!"
        exit 1
    ;;
esac
