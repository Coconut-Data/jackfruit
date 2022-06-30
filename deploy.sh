#!/bin/bash
npx browserify -t coffeeify --extension='.coffee' Jackfruit.coffee -o bundle.js
#cat bundle.js | npx terser | sponge bundle.js