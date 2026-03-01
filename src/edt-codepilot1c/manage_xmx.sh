#!/bin/bash
set -e

INI_FILE="${1:-/opt/1C/1CE/components/1cedt/1cedt.ini}"
XMX_PARAM_PREFIX="-Xmx"
XMX_PARAM="${XMX_PARAM_PREFIX}${EDT_JAVA_XMX:-12g}"

if grep -q "^${XMX_PARAM_PREFIX}" "$INI_FILE" 2>/dev/null; then
  sed -i "s|^${XMX_PARAM_PREFIX}.*|${XMX_PARAM}|" "$INI_FILE"
  echo "Xmx updated in ${INI_FILE}: ${XMX_PARAM}"
else
  echo "${XMX_PARAM}" >> "$INI_FILE"
  echo "Xmx added to ${INI_FILE}: ${XMX_PARAM}"
fi
