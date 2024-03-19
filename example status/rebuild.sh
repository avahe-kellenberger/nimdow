#!/bin/bash
pkill -f "NimdowStatus"
xsetroot -name ""
nimble release
./NimdowStatus &
