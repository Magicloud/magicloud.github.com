#!/usr/bin/env bash
set -eu -o pipefail

title="${1}"
filename="$(tr '[:upper:]' '[:lower:]' <<< "${title}" | tr ' ' '-' )"

d="$(date +'%Y-%m-%d')"
dt="$(date +'%Y-%m-%d %H:%M:%S %z')"

cat > "_posts/${d}-${filename}.markdown" << EOF
---
layout: post
title:  "${title}"
date:   ${dt}
categories:
---
EOF