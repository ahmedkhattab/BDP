#!/bin/bash

./ambari-shell.sh << EOF
blueprint add --url https://goo.gl/7zJ4PX

cluster build --blueprint $BLUEPRINT

cluster autoAssign

cluster create --exitOnFinish true
EOF
