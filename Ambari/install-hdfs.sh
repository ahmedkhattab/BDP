#!/bin/bash

./ambari-shell.sh << EOF
blueprint add --url $BLUEPRINT_URL

cluster build --blueprint $BLUEPRINT

cluster autoAssign

cluster create --exitOnFinish true
EOF
