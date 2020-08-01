#!/bin/bash -e
# SPDX-License-Identifier: CC0-1.0

blake2s_mix() {
    local A_NAME="$1"
    local A="$2"
    local B_NAME="$3"
    local B="$4"
    local C_NAME="$5"
    local C="$6"
    local D_NAME="$7"
    local D="$7"
    local X="$9"
    local Y="${10}"

    A=$(((A + B + X) & 0xffffffff))
    D=$((((D ^ A) << (32 - 16) | (D ^ A) >> 16) & 0xffffffff))
    C=$(((C + D) & 0xffffffff))
    B=$((((B ^ C) << (32 - 12) | (B ^ C) >> 12) & 0xffffffff))
    
    A=$(((A + B + Y) & 0xffffffff))
    D=$((((D ^ A) << (32 - 8) | (D ^ A) >> 8) & 0xffffffff))
    C=$(((C + D) & 0xffffffff))
    B=$((((B ^ C) << (32 - 7) | (B ^ C) >> 7) & 0xffffffff))

    echo "$A_NAME=$A; $B_NAME=$B; $C_NAME=$C; $D_NAME=$D"
}

blake2s() {
    dd bs=64 iflag=fullblock status=none | hexdump -ve '1 1 "%02x\n"' | {
        local IV=(0x6a09e667 0xbb67ae85 0x3c6ef372 0xa54ff53a 0x510e527f 0x9b05688c 0x1f83d9ab 0x5be0cd19)
        local S=(
            0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
            14 10 4 8 9 15 13 6 1 12 0 2 11 7 5 3
            11 8 12 0 5 2 15 13 10 14 3 6 7 1 9 4
            7 9 3 1 13 12 11 14 2 6 5 10 4 0 15 8
            9 0 5 7 2 4 10 15 14 1 11 12 6 8 3 13
            2 12 6 10 0 11 8 3 4 13 7 5 15 14 1 9
            12 5 1 15 14 13 4 10 0 7 6 3 9 2 8 11
            13 11 7 14 12 1 3 9 5 0 15 4 8 6 2 10
            6 15 14 9 11 3 0 8 12 2 13 7 1 4 10 5
            10 2 8 4 7 6 1 5 15 11 9 14 3 12 13 0
        )
        local MLEN=0
        local DLEN="$1"
        # shellcheck disable=SC2155
        local P="$(printf '0x010100%02x' "$DLEN")"
        local H=($((IV[0] ^ P)) $((IV[1])) $((IV[2])) $((IV[3])) $((IV[4])) $((IV[5])) $((IV[6])) $((IV[7])))
        local NEXT
        IFS= read -r NEXT || :
        while :; do
            readarray -tn 63 INPUT
            # shellcheck disable=SC2206
            INPUT=($NEXT "${INPUT[@]}")
            MLEN=$((MLEN + ${#INPUT[@]}))
            local M=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
            for I in $(seq 0 15); do M[$I]="0x${INPUT[$(((I * 4) + 3))]}${INPUT[$(((I * 4) + 2))]}${INPUT[$(((I * 4) + 1))]}${INPUT[$(((I * 4) + 0))]}"; done
            local F=(0 0)
            IFS= read -r NEXT || F[0]=0xffffffff
            local T=(
                $(((MLEN >> 0) & 0xffffffff))
                $(((MLEN >> 32) & 0xffffffff))
            )
            local V=(
                $((H[0]))         $((H[1]))         $((H[2]))         $((H[3]))
                $((H[4]))         $((H[5]))         $((H[6]))         $((H[7]))
                $((IV[0]))        $((IV[1]))        $((IV[2]))        $((IV[3]))
                $((T[0] ^ IV[4])) $((T[1] ^ IV[5])) $((F[0] ^ IV[6])) $((F[1] ^ IV[7]))
            )
            for I in $(seq 0 16 $((9 * 16))); do
                eval "$({
                    blake2s_mix "V[0]" "${V[0]}" "V[4]" "${V[4]}" "V[8]"  "${V[8]}"  "V[12]" "${V[12]}" "${M[S[$((I + 0))]]}"  "${M[S[$((I + 1))]]}" &
                    blake2s_mix "V[1]" "${V[1]}" "V[5]" "${V[5]}" "V[9]"  "${V[9]}"  "V[13]" "${V[13]}" "${M[S[$((I + 2))]]}"  "${M[S[$((I + 3))]]}" &
                    blake2s_mix "V[2]" "${V[2]}" "V[6]" "${V[6]}" "V[10]" "${V[10]}" "V[14]" "${V[14]}" "${M[S[$((I + 4))]]}"  "${M[S[$((I + 5))]]}" &
                    blake2s_mix "V[3]" "${V[3]}" "V[7]" "${V[7]}" "V[11]" "${V[11]}" "V[15]" "${V[15]}" "${M[S[$((I + 6))]]}"  "${M[S[$((I + 7))]]}" &
                } & wait "$!")"
                eval "$({
                    blake2s_mix "V[0]" "${V[0]}" "V[5]" "${V[5]}" "V[10]" "${V[10]}" "V[15]" "${V[15]}" "${M[S[$((I + 8))]]}"   "${M[S[$((I + 9))]]}"  &
                    blake2s_mix "V[1]" "${V[1]}" "V[6]" "${V[6]}" "V[11]" "${V[11]}" "V[12]" "${V[12]}" "${M[S[$((I + 10))]]}"  "${M[S[$((I + 11))]]}" &
                    blake2s_mix "V[2]" "${V[2]}" "V[7]" "${V[7]}" "V[8]"  "${V[8]}"  "V[13]" "${V[13]}" "${M[S[$((I + 12))]]}"  "${M[S[$((I + 13))]]}" &
                    blake2s_mix "V[3]" "${V[3]}" "V[4]" "${V[4]}" "V[9]"  "${V[9]}"  "V[14]" "${V[14]}" "${M[S[$((I + 14))]]}"  "${M[S[$((I + 15))]]}" &
                } & wait "$!")"
            done
            H=(
                $((H[0] ^ V[0] ^ V[8]))
                $((H[1] ^ V[1] ^ V[9]))
                $((H[2] ^ V[2] ^ V[10]))
                $((H[3] ^ V[3] ^ V[11]))
                $((H[4] ^ V[4] ^ V[12]))
                $((H[5] ^ V[5] ^ V[13]))
                $((H[6] ^ V[6] ^ V[14]))
                $((H[7] ^ V[7] ^ V[15]))
            )
            if [ $((F[0])) -ne 0 ]; then break; fi
        done
        for WORD in "${H[@]}"; do
            printf '%02x%02x%02x%02x' "$(((WORD >> 0) & 0xff))" "$(((WORD >> 8) & 0xff))" "$(((WORD >> 16) & 0xff))" "$(((WORD >> 24) & 0xff))"
        done | head -c "$((DLEN * 2))"
    }
    printf '\n'
}

wg_lla() {
    local WORDS
    eval "WORDS=($(base64 -d | blake2s 32 | sed -r 's/[0-9a-f]{4}/0x\0 /g'))"
    printf '%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x\n' "$((0xfe80 | (WORDS[0] & 0x003f)))" "${WORDS[1]}" "${WORDS[2]}" "${WORDS[3]}" "${WORDS[4]}" "${WORDS[5]}" "${WORDS[6]}" "${WORDS[7]}"
}

IFACES=("$@")

DRY_RUN=1
if [ $# -gt 1 ] && [ "${IFACES[${#IFACES[@]} - 1]}" == "assign" ]; then
    unset 'IFACES[${#IFACES[@]} - 1]'
    DRY_RUN=0
fi

if [ ${#IFACES[@]} -eq 0 ]; then
    printf 'Usage: %s { <interface> | all | interfaces } [assign]\n\n' "$(basename "$0")" 1>&2
    printf 'Calculates cryptographically-bound IPv6 Link-Local Addresses for the specified\n' 1>&2
    printf 'WireGuard interface(s) and its peers.\n' 1>&2
    exit 1
fi

if [ ${#IFACES[@]} -eq 1 ] && [ "${IFACES[0]}" == "all" ]; then
    read -ra IFACES <<EOF
$(wg show interfaces)
EOF
fi

for IFACE in "${IFACES[@]}"; do
    IFACE_KEY="$(wg show "$IFACE" public-key)"
    IFACE_LLA="$(printf '%s' "$IFACE_KEY" | wg_lla)"
    printf '%s\t%s/10\n' "$IFACE_KEY" "$IFACE_LLA"
    if [ "$DRY_RUN" -eq 0 ]; then
        ip address add "$IFACE_LLA/10" dev "$IFACE" 2>/dev/null || :
    fi
    wg show "$IFACE" allowed-ips | while read -r LINE; do
        PEER="$(printf '%s' "$LINE" | cut -f 1)"
        ALLOWED_IPS="$(printf '%s' "$LINE" | cut -f 2)"
        LLA="$(printf '%s' "$PEER" | wg_lla)"
        printf '%s\t%s/128\n' "$PEER" "$LLA"
        if [ "$DRY_RUN" -eq 0 ]; then
            wg set "$IFACE" peer "$PEER" allowed-ips "$(printf '%s' "$ALLOWED_IPS" | sed -r 's/\s+/,/g'),$LLA/128"
        fi
    done
done
