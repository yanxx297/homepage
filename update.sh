#! /bin/bash

hugo
find ./public/ -type f -exec chmod 644 {} +
rsync -av public/ ~/.www/
chmod 701 ~/.www/
