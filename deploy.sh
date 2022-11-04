#!/bin/bash
echo "Packaging source code together into bundle.js"
npx browserify -t coffeeify --extension='.coffee' Jackfruit.coffee -o bundle.js
echo "Compressing bundle.js"
cat bundle.js | npx terser | npx sponge bundle.js
echo "Copying results to server"
rsync --progress --verbose --copy-links --exclude=.git --exclude=node_modules --recursive ./ karafuu@coconut.mohz.go.tz:/var/www/jackfruit/
