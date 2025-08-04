#!/bin/bash

for i in {0..15}; do
    printf "\e[48;5;${i}m %3s \e[0m" "$i"
    if (( (i + 1) % 8 == 0 )); then
        echo
    fi
done
echo

for i in {16..231}; do
    printf "\e[48;5;${i}m %3s \e[0m" "$i"
    if (( (i - 15) % 6 == 0 )); then
        echo
    fi
done
echo

for i in {232..255}; do
    printf "\e[48;5;${i}m %3s \e[0m" "$i"
    if (( (i - 15) % 6 == 0 )); then
        echo
    fi
done
echo

for fg in {30..37}; do
    for bg in {40..47}; do
        printf "\e[${fg};${bg}m fg${fg}-bg${bg} \e[0m  "
    done
    echo
done
