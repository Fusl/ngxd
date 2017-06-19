#!/usr/bin/env node

var fs = require('fs');
var dot = require('dot');

var cfg = require('./nginx.json');

var template = fs.readFileSync('./nginx.tpl').toString('utf8');

dot.templateSettings.strip = false;
dot.templateSettings.append = false;
dot.templateSettings.selfcontained = false;
dot.templateSettings.varname = 'dot';

cfg.exec = function () {
	var args = Array.prototype.slice.call(arguments);
	return eval(args.shift()).apply(this,args);
};

console.log(dot.template(template)(cfg));
