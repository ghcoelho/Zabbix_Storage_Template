// Copyright 2007-2012 futomi  http://www.html5.jp/
//
// Licensed under The MIT License;
// http://www.opensource.org/licenses/mit-license.php
//
// jquery.html5jpMeterPolyfill.js v1.0.0

(function(jQuery) {

var dummy_meter = document.createElement('meter');

jQuery.fn.html5jpMeterPolyfill = function(preference) {
	// if the UA supports <meter>, do nothing.
	if( 'value' in dummy_meter ) { return; }
	//
	var op = jQuery.extend({
		color_stops: [
			// color stop list for background
			[ [0, '#DEDEDE'], [0.2, '#EDEDED'], [0.4, '#CCCCCC'], [0.75, '#D3D3D3'], [1, '#DDDDDD '] ],
			// color stop list for optimum region (green)
			[ [0, '#ABDD78'], [0.2, '#CBEDA8'], [0.4, '#77AA33'], [0.75, '#8DC051'], [1, '#AADD76'] ],
			// color stop list for suboptimal region (yellow)
			[ [0, '#FFEE79'], [0.2, '#FFFEC9'], [0.4, '#DDBB33'], [0.75, '#E9CD4B'], [1, '#FEED75'] ],
			// color stop list for even less good region (red)
			[ [0, '#FF7979'], [0.2, '#FEC9C9'], [0.4, '#DD4444'], [0.75, '#ED5C5C'], [1, '#FF7777'] ]
		]
	}, preference);
	//
	var fnDraw = function(){};
	if( 'getContext' in document.createElement('canvas') ) {
		fnDraw = drawByCanvas;
	} else if( document.uniqueID ) {
		if (!document.namespaces['v']) {
			document.namespaces.add('v', 'urn:schemas-microsoft-com:vml');
			var style_sheet = document.createStyleSheet();
			style_sheet.cssText = "v\\:rect, v\\:fill, v\\:group { behavior: url(#default#VML); display:inline-block; }";
		}
		fnDraw = drawByVml;
	}
	//
	return jQuery(this).each(function() {
		// the meter element
		var meter = jQuery(this);
		if( ! meter.prop('nodeName').match(/^meter$/i) ) {
			return;
		}
		meter.css({
			'padding' : '0px',
			'overflow': 'hidden'
			});
		// get attributes
		var attrs = getAttr(meter);
		// determin the optimum reagion
		var region = getRegion(attrs);
		// determin width/height
		var w = meter.innerWidth();
		var h = meter.innerHeight();
		// draw the meter
		fnDraw({
			meter  : meter,
			w      : w,
			h      : h,
			p      : w * (attrs.value - attrs.min) / (attrs.max - attrs.min),
			region : region,
			op     : op
		});
	});
};

function getRegion(attrs) {
	var value   = attrs.value;
	var min     = attrs.min;
	var max     = attrs.max;
	var low     = attrs.low;
	var high    = attrs.high;
	var optimum = attrs.optimum;
	// determin which region the value is put in.
	// 1: optimum region
	// 2: suboptimal region
	// 3: even less good region
	var region = 3; 
	if( optimum >= low && optimum <= high ) {
		if( attrs.value >= low && value <= high ) {
			region = 1;
		} else {
			region = 2;
		}
	} else if( optimum < low ) {
		if( value <= low ) {
			region = 1;
		} else if( value >= low && value <= high ) {
			region = 2;
		}
	} else if( optimum > high ) {
		if( value >= high ) {
			region = 1;
		} else if( value >= low && value < high ) {
			region = 2;
		}
	}
	return region;
}

function getAttr(meter) {
	// @min
	var min = meter.attr('min');
	min = ( min !== undefined && /^\d+$/.test(min) ) ? parseFloat(min, 10) : 0;
	// @max
	var max = meter.attr('max');
	max = ( max !== undefined && /^\d+$/.test(max) ) ? parseFloat(max, 10) : 1;
	if( max < min ) { max = min; }
	// @value
	var value = meter.attr('value');
	value = ( value !== undefined && /^\d+$/.test(value) ) ? parseFloat(value, 10) : 0;
	if(value < min) {
		value = min;
	} else if(value > max) {
		value = max;
	}
	// @low
	var low = meter.attr('low');
	low = ( low !== undefined && /^\d+$/.test(low) ) ? parseFloat(low, 10) : min;
	if(low < min) {
		low = min;
	} else if(low > max) {
		low = max;
	}
	// @high
	var high = meter.attr('high');
	high = ( high !== undefined && /^\d+$/.test(high) ) ? parseFloat(high, 10) : max;
	if(high < low) {
		high = low;
	} else if(high > max) {
		high = max;
	}
	// @optimum
	var optimum = meter.attr('optimum');
	optimum = ( optimum !== undefined && /^\d+$/.test(optimum) ) ? parseFloat(optimum, 10) : ((min + max) / 2);
	if(optimum < min) {
		optimum = min;
	} else if(optimum > max) {
		optimum = max;
	}
	//
	return {
		value   : value,
		min     : min,
		max     : max,
		low     : low,
		high    : high,
		optimum : optimum
	};
}

function drawByCanvas(params) {
	var canvas = null;
	if( params.meter.find('canvas.html5jp-meter-polyfill').length > 0 ) {
		canvas = params.meter.find('canvas.html5jp-meter-polyfill').get(0);
	} else {
		canvas = document.createElement('canvas');
		jQuery(canvas).addClass('html5jp-meter-polyfill');
		jQuery(canvas).css({
			'margin'  : '0px',
			'padding' : '0px'
		});
		jQuery(canvas).html( params.meter.html() );
		params.meter.empty();
		params.meter.append(jQuery(canvas));
	}
	canvas.width = params.w;
	canvas.height = params.h;
	var ctx = canvas.getContext('2d');
	ctx.clearRect(0, 0, params.w, params.h);
	// draw the background
	var grad_bg = ctx.createLinearGradient(0, 0, 0, params.h);
	var bg_color_stops = params.op.color_stops[0];
	for( var i=0; i<bg_color_stops.length; i++ ) {
		var stop = bg_color_stops[i];
		grad_bg.addColorStop(stop[0], stop[1]);
	}
	ctx.fillStyle = grad_bg;
	ctx.beginPath();
	ctx.rect(0, 0, params.w, params.h);
	ctx.fill();
	// draw the foreground
	var grad_fg = ctx.createLinearGradient(0, 0, 0, params.h);
	var fg_color_stops = params.op.color_stops[params.region];
	for( var i=0; i<fg_color_stops.length; i++ ) {
		var stop = fg_color_stops[i];
		grad_fg.addColorStop(stop[0], stop[1]);
	}
	ctx.fillStyle = grad_fg;
	ctx.beginPath();
	ctx.rect(0, 0, params.p, params.h);
	ctx.fill();
}

function drawByVml(params) {
	var w = parseFloat( params.meter.attr('data-html5jp-w'), 10);
	var h = parseFloat( params.meter.attr('data-html5jp-h'), 10);
	if( w ) {
		params.w = w;
		params.h = h;
	} else {
		params.meter.attr({
			'data-html5jp-w': params.w,
			'data-html5jp-h': params.h
		});
	}
	//
	var vml = '';
	vml += '<v:group  coordsize="' + params.w + ' ' + params.h + '" coordorigin="0 0" style="position:relative; left:0px; top:0px; padding:0px; margin:0px; width:' + params.w + 'px; height:' + params.h + 'px;">';
	// draw the background
	vml += '<v:rect style="left:0px; top:0px; padding:0px; margin:0px; width:' + params.w + 'px; height:' + params.h + 'px;" filled="true" stroked="false">';
	var bg_color_stops = params.op.color_stops[0];
	vml += '<v:fill type="gradient" method="linear" angle="180" color="' + bg_color_stops[0][1] + '" color2="' + bg_color_stops[bg_color_stops.length-1][1] + '"';
	var bg_colors = [];
	for( var i=0; i<bg_color_stops.length; i++ ) {
		var stop = bg_color_stops[i];
		var pos = parseFloat(stop[0], 10);
		if( pos !== 0 && pos !== 1 ) {
			bg_colors.push( ( pos * 100 ) + '% ' + stop[1] );
		}
	}
	if( bg_colors.length > 0 ) {
		vml += ' colors="';
		vml += bg_colors.join(', ');
		vml += '"';
	}
	vml += '/>';
	vml += '</v:rect>';
	// draw the foreground
	if( params.p > 0 ) {
		vml += '<v:rect style="left:0px; top:0px; padding:0px; margin:0px; width:' + params.p + 'px; height:' + params.h + 'px;" filled="true" stroked="false">';
		var fg_color_stops = params.op.color_stops[params.region];
		vml += '<v:fill type="gradient" method="linear" angle="180" color="' + fg_color_stops[0][1] + '" color2="' + fg_color_stops[fg_color_stops.length-1][1] + '"';
		var fg_colors = [];
		for( var i=0; i<fg_color_stops.length; i++ ) {
			var stop = fg_color_stops[i];
			var pos = parseFloat(stop[0], 10);
			if( pos !== 0 && pos !== 1 ) {
				fg_colors.push( ( pos * 100 ) + '% ' + stop[1] );
			}
		}
		if( fg_colors.length > 0 ) {
			vml += ' colors="';
			vml += fg_colors.join(', ');
			vml += '"';
		}
		vml += '/>';
		vml += '</v:rect>';
	}
	vml += '</v:group>';
	params.meter.empty();
	params.meter.html(vml);
}

})(jQuery);

