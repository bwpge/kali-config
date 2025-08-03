#!/bin/bash

for fg_color in {30..37} {90..97}; do
    for bg_color in {40..47} {100..107}; do
        echo -ne "\e[${fg_color};${bg_color}m  \e[0m"
    done
    echo
done

# echo -e "\nBasic formatting:"
# echo -e "\e[1mBold Text\e[0m"
# echo -e "\e[4mUnderlined Text\e[0m"
# echo -e "\e[5mBlinking Text (may not work on all terminals)\e[0m"
# echo -e "\e[7mInverted Text\e[0m"
# echo -e "\e[8mHidden Text (select to reveal)\e[0m"
# echo -e "\e[0m" # Reset all attributes
