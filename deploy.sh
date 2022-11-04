#!/bin/bash
echo "Packaging source code together into bundle.js"
npx browserify -t coffeeify --extension='.coffee' Jackfruit.coffee -o bundle.js
echo "Compressing bundle.js"
cat bundle.js | npx terser | sponge bundle.js
echo "Copying results to server"
rsync --progress --verbose --copy-links --exclude=node_modules --recursive ./ jackfruit.cococloud.co:/var/www/jackfruit.cococloud.co/
