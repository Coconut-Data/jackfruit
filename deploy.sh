#!/bin/bash
npx browserify -t coffeeify --extension='.coffee' Jackfruit.coffee -o bundle.js
cat bundle.js | npx terser | sponge bundle.js
pushd dist
aws s3 sync . s3://jackfruit/
popd
#rsync --progress --verbose --copy-links --exclude=node_modules --recursive ./ jackfruit.cococloud.co:/var/www/jackfruit.cococloud.co/
