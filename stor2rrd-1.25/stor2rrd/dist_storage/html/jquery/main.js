var hashTable = {},
sysInfo = {},
curLoad,
curNode,
curTab,
jumpTo,
browserNavButton = false,
fleet = {},
mailGroups = {},
alrtCfg = {},
storedUrl,
zoomedUrl,
storedObj,
timeoutHandle,
loaded = 0;
prodName = "STOR2RRD";

var tabHead = {
	'total': "Total",
	'read': "Read",
	'write': "Write",
	'resp': "Response time total",
	'resp tot': "Response time total",
	'resp read': "Response time read",
	'resp write': "Response time write",
	'resp read back': "Response time read - back",
	'resp write back': "Response time write - back",
	'resp_t_r_b': "Response time read - back",
	'resp_t_w_b': "Response time write - back",
	'sum_io': "IO total",
	'sum_data': "Data total",
	'IO tot': "IO total",
	'io_rate': "IO total",
	'data tot': "Data total",
	'data_rate': "Data total",
	'IO read': "IO Read",
	'IO write': "IO Write",
	'IO read back': "IO Read - back",
	'IO write back': "IO Write - back",
	'read_io_b': "IO Read - back",
	'write_io_b': "IO Write - back",
	'read back': "Read data - back",
	'write back': "Write data - back",
	'read avg': "Read average",
	'write avg': "Write average",
	'read usage': "Read usage",
	'write usage': "Write usage",
	'read hit': "Read hit",
	'write hit': "Write hit",
	'sys': "CPU system",
	compress: "CPU compress",
	sum_capacity: "Capacity",
	used: "Capacity used",
	real: "Capacity real",
	r_cache_usage: "Read cache usage",
	w_cache_usage: "Write cache usage",
	'read cache hit': "Read cache hit",
	'write cache hit': "Write cache hit",
	pprc_rio: "PPRC read IO",
	pprc_wio: "PPRC write IO",
	pprc_data_r: "PPRC read data",
	pprc_data_w: "PPRC write data",
	pprc_rt_r: "PPRC response time read",
	pprc_rt_w: "PPRC response time write",
	"CPU": "CPU node",
	io_cntl: "controller",
	ssd_r_cache_hit: "SSD read cache hit",
	cache_hit: "cache hit",
	data_cntl: "controller",
	read_pct: "read percent",
	sum_io_total: "SAN agg IO total",
	san_data_sum_in: "SAN IN",
	san_data_sum_out: "SAN OUT",
	san_data_sum_credits: "SAN credits",
	san_data_sum_crc_errors: "SAN CRC errors",
	san_data_sum_encoding_errors: "SAN encoding errors",
	san_io_sum_in: "SAN IO IN",
	san_io_sum_out: "SAN .OUT",
	san_data: "SAN data",
	san_io: "SAN frames",
	san_credits: "SAN credits",
	san_errors: "SAN errors",
	"custom-group-io_rate": "IO rate",
	"custom-group-data_rate": "data rate",
	"custom-group-read_io": "read IO",
	"custom-group-write_io": "write IO",
	"custom-group-read": "read",
	"custom-group-write": "write", // end of short dashboard hashes
    san_data_sum_tot_in: "SAN IN",
    san_data_sum_tot_out: "SAN OUT",
    san_data_sum_tot_credits: "SAN Credits",
    san_data_sum_tot_crc_errors: "SAN CRC errors",
    san_data_sum_tot_encoding_errors: "SAN Encoding errors",
    san_io_sum_tot_in: "SAN fabric IN",
    san_io_sum_tot_out: "SAN fabric OUT",
    san_fabric_data_in: "SAN fabric Data in",
    san_fabric_frames_in: "SAN fabric Frames in",
    san_fabric_credits: "SAN fabric Credits",
    san_fabric_crc_errors: "SAN fabric CRC errors",
    san_fabric_encoding_errors: "SAN fabric Encoding errors",
    san_fabric_conf: "SAN fabric Configuration"
};

var urlItems = {
	resp: [ "response time total", "xa" ],
	resp_t: [ "response time total", "xb" ],
	resp_t_r: [ "response time read", "xc" ],
	resp_t_w: [ "response time write", "xd" ],
	resp_t_r_b: [ "response time read - back", "xe" ],
	resp_t_w_b: [ "response time write - back", "xf" ],
	sum_io: [ "IO total", "xg" ],
	sum_data: [ "data total", "xh" ],
	io: [ "IO total", "xi" ],
	io_rate: [ "IO total", "xj" ],
	data: [ "data total", "xk" ],
	data_rate: [ "data total", "xl" ],
	read_io: [ "read IO", "xm" ],
	write_io: [ "write IO", "xn" ],
	read_io_b: [ "read IO - back", "xo" ],
	write_io_b: [ "write IO - back", "xp" ],
	read: [ "read data", "xq" ],
	write: [ "write data", "xr" ],
	read_b: [ "read data - back", "xs" ],
	write_b: [ "write data - back", "xt" ],
	sys: [ "CPU system", "xu" ],
	compress: [ "CPU compress", "xv" ],
	sum_capacity: [ "capacity", "xw" ],
	used: [ "capacity used", "xx" ],
	real: [ "capacity real", "xy" ],
	r_cache_usage: [ "read cache usage", "xz" ],
	w_cache_usage: [ "write cache usage", "xA" ],
	r_cache_hit: [ "read cache hit", "xB" ],
	w_cache_hit: [ "write cache hit", "xC" ],
	pprc_rio: [ "PPRC read IO", "xD" ],
	pprc_wio: [ "PPRC write IO", "xE" ],
	pprc_data_r: [ "PPRC read data", "xF" ],
	pprc_data_w: [ "PPRC write data", "xG" ],
	pprc_rt_r: [ "PPRC response time read", "xH" ],
	pprc_rt_w: [ "PPRC response time write", "xI" ],
	io_cntl: [ "controller", "xJ" ],
	ssd_r_cache_hit: [ "SSD read cache hit", "xK" ],
	cache_hit: [ "cache hit", "xL" ],
	data_cntl: [ "controller", "xM" ],
	read_pct: [ "read percent", "xN" ],
	sum_io_total: [ "agg IO total", "xO" ],
	san_data_sum_in: ["IN", "xQ" ],
	san_data_sum_out: ["OUT", "xR" ],
	san_io_sum_credits: ["credits", "xS" ],
	san_io_sum_crc_errors: ["CRC errors", "xT" ],
	san_io_sum_encoding_errors: ["encoding errors", "xU" ],
	san_io_sum_in: ["IN", "xV" ],
	san_io_sum_out: ["OUT", "xW" ],
	san_data: ["data", "xX" ],
	san_io: ["frames", "xY" ],
	san_credits: ["credits", "xZ" ],
	san_errors: ["errors", "x0" ],
	"custom-group-io_rate": ["IO rate", "x1" ],
	"custom-group-data_rate": ["data rate", "x2" ],
	"custom-group-read_io": ["read IO", "x3" ],
	"custom-group-write_io": ["write IO", "x4" ],
	"custom-group-read": ["read", "x5" ],
	"custom-group-write": ["write", "x6" ], // end of short dashboard hashes
    san_data_sum_tot_in: ["IN", "aa" ],
    san_data_sum_tot_out: ["OUT", "ab" ],
    san_io_sum_tot_credits: ["Credits", "ac" ],
    san_io_sum_tot_crc_errors: ["CRC errors", "ad" ],
    san_io_sum_tot_encoding_errors: ["Encoding errors", "ae" ],
    san_io_sum_tot_in: ["IN", "af" ],
    san_io_sum_tot_out: ["OUT", "ag" ],
    san_fabric_data_in: ["Data in", "ah" ],
    san_fabric_frames_in: ["Frames in", "ai" ],
    san_fabric_credits: ["Credits", "aj" ],
    san_fabric_crc_errors: ["CRC errors", "ak" ],
    san_fabric_encoding_errors: ["Encoding errors", "al" ],
    san_fabric_conf: ["Configuration", "am" ],
    tier0: ["Tier 0", "an" ],
    tier1: ["Tier 1", "ao" ],
    tier2: ["Tier 2", "ap" ],
    "custom-group-data_in": ["Data IN", "aq" ],
    "custom-group-data_out": ["Data OUT", "ar" ],
    "custom-group-frames_in": ["Frames IN", "as" ],
    "custom-group-frames_out": ["Frames OUT", "at" ],
    "custom-group-credits": ["Credits", "au" ],
    "custom-group-errors": ["Errors", "av" ],
	"san_isl_data_in": ["Data in", "aw" ],
	"san_isl_data_out": ["Data out", "ax" ],
	"san_isl_frames_in": ["Frames in", "ay" ],
	"san_isl_frames_out": ["Frames out", "az" ],
	"san_isl_credits": ["BBCredits", "ba" ],
	"san_isl_crc_errors": ["CRC errors", "bb" ],
	"write_pend": ["Write pending", "bc" ],
	"clean_usage": ["Clean queue", "bd" ],
	"middle_usage": ["Middle queue", "be" ],
	"phys_usage": ["Physical queue", "bf" ],
	"operating_rate": ["Operating rate", "bg" ],
};

// cap, io, data, resp, cache, cpu, pprc


/*
if (!Object.keys) { // IE8 hack
	Object.keys = function(obj) {
		var keys = [];

		for (var i in obj) {
			if (obj.hasOwnProperty(i)) {
				keys.push(i);
			}
		}

		return keys;
	};
}

var urlItems = Object.keys(urlItem);
*/

jQuery.extend({ alert: function (message, title, status) {
	title += (status ? " - SUCCESS" : " - FAILURE");
	$("<div></div>").dialog( {
		buttons: { "Ok": function () { $(this).dialog("close"); } },
		close: function (event, ui) { $(this).remove(); },
		resizable: false,
		title: title,
		minWidth: 700,
		modal: true
	}).html("<pre>" + message + "</pre>");
	}
});


var intervals = {
	d: "Last day",
	w: "Last week",
	m: "Last month",
	y: "Last year"
};

$(document).ready(function() {
	$.ajaxSetup({
		traditional: true
	});

	// Bind to StateChange Event
	History.Adapter.bind(window, 'statechange', function() { // Note: We are using statechange instead of popstate
		var state = History.getState(); // Note: We are using History.getState() instead of event.state
		var menuTree = $("#side-menu").fancytree("getTree");
		if (state.data.menu && state.internal) {
			curTab = state.data.tab;
			browserNavButton = true;
			if (state.data.form) {
				var data = restoreData(state.data.form);
				$("#content").html(data.html);
				myreadyFunc();
				$("#content").scrollTop(data.scroll);
				$("#title").html(data.title);
			} else if (state.data.menu == menuTree.getActiveNode().key) {
				menuTree.reactivate();
			} else {
				menuTree.activateKey(state.data.menu);
			}
		}
	});


	$.getJSON("/stor2rrd-cgi/genjson.sh?jsontype=env", function(data) {
		$.each(data, function(key, val) {
			sysInfo[key] = val;
		});
		if (sysInfo.sideMenuWidth) {
			less.modifyVars({ sideBarWidth : sysInfo.sideMenuWidth + 'px' });
		}
		if (sysInfo.beta == "1") {
			if (!$.cookie('beta-notice')) {
				$.cookie('beta-notice', 'displayed', {
					expires: 0.25
				}); // 0.007 = 10 minutes
				$("#beta-notice").load("beta-notice.html");
				$("#beta-notice").dialog("open");
			}
		}
		if (sysInfo.guidebug == 1) {
			$("#savecontent input:submit").button();
			$("#savecontent").show();
		}
		var logo = "<a href='http://www.stor2rrd.com/' target='_blank'><img src='css/images/logo-stor2rrd.png' alt='STOR2RRD HOME' title='STOR2RRD HOME' style='float: left; margin-top: 13px; margin-left:12px; border: 0; opacity: 0.7;'></a>";

		// white labeling
		if (sysInfo.wlabel) {
			prodName = sysInfo.wlabel;
			switch(prodName) {
			case "7eysight":
				logo = "<a href='http://www.7eysight.com/' target='_blank'><img src='css/images/7eysight_logo.png' alt='7eysight HOME' title='7eysight HOME' style='float: left; margin-top: 4px; margin-left:22px; border: 0; opacity: 0.8;'></a>";
			$( "#header" ).css("background", "#23A0E5");
				break;
			}
		}
		$( logo ).insertBefore( "#subheader" );
	});

	$("#beta-notice").dialog({
		dialogClass: "info",
		minWidth: 500,
		modal: true,
		autoOpen: false,
		show: {
			effect: "fadeIn",
			duration: 500
		},
		hide: {
			effect: "fadeOut",
			duration: 200
		},
		buttons: {
			OK: function() {
				$(this).dialog("close");
			}
		}
	});
	$("#data-src-info").dialog({
		dialogClass: "info",
		minWidth: 400,
		modal: true,
		autoOpen: false,
		show: {
			effect: "fadeIn",
			duration: 500
		},
		hide: {
			effect: "fadeOut",
			duration: 200
		},
		position: {
			my: "right top",
			at: "right top",
			of: $("#content")
		},
		buttons: {
			OK: function() {
				$(this).dialog("close");
			}
		}
	});
	$("#rperf-notice").dialog({
		dialogClass: "info",
		minWidth: 500,
		modal: true,
		autoOpen: false,
		show: {
			effect: "fadeIn",
			duration: 500
		},
		hide: {
			effect: "fadeOut",
			duration: 200
		},
		buttons: {
			OK: function() {
				$(this).dialog("close");
			}
		}
	});

	$("#side-menu").fancytree({
		extensions: ["filter", "persist"],
		source: {
			url: '/stor2rrd-cgi/genjson.sh?jsontype=menuh'
		},
		filter: {
			mode: "hide"
		},
		icons: false,
		selectMode: 1,
		clickFolderMode: 2,
		activate: function(event, data) {
			if (curNode != data.node) {
				if (curNode && !browserNavButton) {
					curTab = 0;
				}
				curNode = data.node;
			}
			if (curNode.data.href) {
				autoRefresh();
				var url = curNode.data.href;
				if (curLoad) {
					curLoad.ajaxStop(); //cancel previous load
				}
				$('#content').empty();
				$('#content').append("<div style='width: 100%; height: 100%; text-align: center'><img src='css/images/sloading.gif' style='margin-top: 200px'></div>");
				$('#subheader fieldset').hide();
				if (url.indexOf("capacity.html") >= 0) {
					setTitle(curNode);
					if (curNode.data.hash) {
						urlMenu = curNode.data.hash;
					} else {
						urlMenu = curNode.key.substring(1);
					}
					History.pushState({
						menu: curNode.key,
						tab: 0
					}, "STOR2RRD - " + $('#title').text(), '?menu=' + urlMenu + "&tab=" + 0);
					browserNavButton = false;
					genCapacity();
					return;
				}
				curLoad = $('#content').load(url, function() {
					imgPaths();
					setTimeout(function() {
						myreadyFunc();
						setTitle(curNode);
						var tabName = "";
						if ($('#tabs').length) {
							tabName = " [" + $('#tabs li.ui-tabs-active').text() + "]";
						}
						if (curNode.data.hash) {
							urlMenu = curNode.data.hash;
						} else {
							urlMenu = curNode.key.substring(1);
						}
						History.pushState({
							menu: curNode.key,
							tab: curTab
						}, "STOR2RRD - " + $('#title').text() + tabName, '?menu=' + urlMenu + "&tab=" + curTab);
						browserNavButton = false;
					}, 10);
				});
			}
		},
		click: function(event, data) { // allow re-loads
			var node = data.node;
			if (!node.isExpanded()) {  // jump directly to POOL/IO when opening storage
				if (node.getLevel() == 2) {
					if (node.data.type   == "SAN") {
						node.visit(function(pNode) {
							if (pNode.title == "Data") {
								event.preventDefault();
								pNode.setActive();
								pNode.makeVisible({
									noAnimation: true,
									noEvents: true,
									scrollIntoView: true
								});
								// chNode.setExpanded()
								return false;
							}
						});
					} else {
						var leaveMe = false;
						node.visit(function(chNode) {
							if ( sysInfo.jump_to_rank && (chNode.title == "RANK" || chNode.title == "Managed disk" || chNode.title == "RAID GROUP") || (!sysInfo.jump_to_rank && (chNode.title == "POOL" || chNode.title == "RAID GROUP")) ) {
								chNode.visit(function(pNode) {
									if (pNode.title == "IO" || pNode.title == "Data") {
										event.preventDefault();
										pNode.setActive();
										pNode.makeVisible({
											noAnimation: true,
											noEvents: true,
											scrollIntoView: true
										});
										// chNode.setExpanded()
										leaveMe = true;
										return false;
									}
								});
							}
							if (leaveMe) {
								return false;
							}
						});
					}
				}
				else if (node.getLevel() == 3) {
					node.visit(function(chNode) {
						if ( chNode.title == "IO") {
							event.preventDefault();
							chNode.setActive();
							chNode.makeVisible({
								noAnimation: true,
								noEvents: true,
								scrollIntoView: true
							});
							// chNode.setExpanded()
							return false;
						}
					});
				}
			}
			if (node.isActive() && node.data.href) {
				data.tree.reactivate();
			}
		},
		init: function() {
			var $tree = $(this).fancytree("getTree");
			var menuPos = getUrlParameter('menu');
			var tabPos = getUrlParameter('tab');
			checkStatus();
			if (tabPos) {
				curTab = tabPos;
			}
			if (menuPos) {
				if (menuPos == "extnmon") {
					var href = window.location.href;
					var qstr = href.slice(href.indexOf('&start-hour') + 1);
					var hashes = qstr.split('&');
					// var txt = hashes[13].split("=")[1];
					var txt = decodeURIComponent(hashes[14].split("=")[1]);

					txt = txt.replace("--unknown","");
					txt = txt.replace("--NMON--","");
					$("#content").load("/lpar2rrd-cgi/lpar2rrd-external-cgi.sh?" + qstr, function(){
						imgPaths();
						$('#title').text(txt);
						$('#title').show();
						myreadyFunc();
						// loadImages('#content img.lazy');
						if (timeoutHandle) {
							clearTimeout(timeoutHandle);
						}
					});
				} else {
					$tree.visit(function(node) {
						if (node.data.hash == menuPos) {
							node.setExpanded(true);
							node.setActive();
							return false;
						}
					});
				}
			}
			else if (!$tree.activeNode) {
				$tree.getFirstChild().setActive();
			}
			hashTable = [];
			$tree.visit(function(node) {
				if (sysInfo.guidebug == 1) {
					node.tooltip = node.data.href;
					node.renderTitle();
				}
				if (node.data.hash) {
					var type = node.data.href.match(/type=([^&]*)/i);
					if (type) {
						type = type[1];
					}
					if (node.data.agg) {
						hashTable[node.data.hash] = {
							"hmc": node.data.hmc,
							"srv": node.data.srv,
							"lpar": "sum",
							"type": type
						};
					} else if (node.data.altname) {
						hashTable[node.data.hash] = {
							"hmc": node.data.hmc,
							"srv": node.data.srv,
							"lpar": node.data.altname,
							"longname": node.title,
							"type": type
						};
					} else {
						hashTable[node.data.hash] = {
							"hmc": node.data.hmc,
							"srv": node.data.srv,
							"lpar": node.title,
							"type": type
						};
					}
				}
			});
		}
	});

	var $tree = $("#side-menu").fancytree("getTree");

	$("#lparsearch").submit(function(event) {
		event.preventDefault();
		if (timeoutHandle) {
			clearTimeout(timeoutHandle);
		}
		$('#content').empty();

		$('#content').append("<div style='width: 100%; height: 100%; text-align: center'><img src='css/images/sloading.gif' style='margin-top: 200px'></div>");
		$('#title').text("LPAR search results");
		var postData = $(this).serialize();
		if (sysInfo.guidebug == 1) {
			copyToClipboard(postData);
		}
		$('#content').load(this.action, postData, function() {
			if (curNode.data.hash) {
				urlMenu = curNode.data.hash;
			} else {
				urlMenu = curNode.key.substring(1);
			}
			History.pushState({
				menu: curNode.key,
				tab: curTab,
				form: "lparsrch"
			}, "LPAR2RRD - LPAR Search Form Results", '?menu=' + urlMenu + "&tab=" + curTab);
			imgPaths();
			myreadyFunc();
			saveData("lparsrch"); // save when page loads

		});
	});

	/* BUTTONS */

	$("#collapseall").button({
		text: false,
		icons: {
			primary: "ui-icon-minus"
		}
	})
		.click(function() {
			$tree.visit(function(node) {
				node.setExpanded(false, {
					noAnimation: true,
					noEvents: true
				});
			});
		});
	$("#expandall").button({
		text: false,
		icons: {
			primary: "ui-icon-plus"
		}
	})
		.click(function() {
			$tree.visit(function(node) {
				node.setExpanded(true, {
					noAnimation: true,
					noEvents: true
				});
			});
		});
	$("#filter").button({
		text: false,
		icons: {
			primary: "ui-icon-search"
		}
	})
		.click(function() {
			// Pass text as filter string (will be matched as substring in the node title)
			var match = $("#menu-filter").val();
			if ($.trim(match) !== "") {
				var re = new RegExp(match, "i");
				var n = $tree.filterNodes(function(node) {
					var parentTitle = node.parent.title;
					var matched = re.test(node.data.str);
					if (matched) {
						node.setExpanded(true, true);
						if (parentTitle != "Removed") {
							if ((parentTitle != "Items") || ((parentTitle == "Items") && re.test(node.title))) {
								node.makeVisible({
									noAnimation: true,
									noEvents: true,
									scrollIntoView: false
								});
							}
						}
					}
					return matched;
				});
				// $("#expandall").click();
				$("#clrsrch").button("enable");
			}
		});

	$("#clrsrch").button({
		text: false,
		disabled: true,
		icons: {
			primary: "ui-icon-close"
		}
	})
		.click(function() {
			$("#menu-filter").val("");
			$tree.clearFilter();
			$(this).button("disable");
		});

	/*
	* Event handlers for menu filtering
	*/
	$("#menu-filter").keypress(function(event) {
		var match = $(this).val();
		if (event.which == 13) {
			event.preventDefault();
			if (match > "") {
				$("#filter").click();
			}
		}
		if (event.which == 27 || $.trim(match) === "") {
			$("#clrsrch").click();
		}
	}).focus();

	if (navigator.userAgent.indexOf('MSIE') >= 0) { // MSIE
		placeholder();
		$("input[type=text]").focusin(function() {
			var phvalue = $(this).attr("placeholder");
			if (phvalue == $(this).val()) {
				$(this).val("");
			}
		});
		$("input[type=text]").focusout(function() {
			var phvalue = $(this).attr("placeholder");
			if ($(this).val() === "") {
				$(this).val(phvalue);
			}
		});
		$("#menu-filter").blur();
	}

	$("#savecontent").submit(function(event) {
		var conf = confirm("This will generate file named <debug.txt> containing HTML code of main page. Please save it to disk and attach to the bugreport");
		if (conf === true) {
			var postDataObj = {
				html: "<!-- " + navigator.userAgent + "-->\n" + $("#content").html()
			};
			var postData = "<!-- " + navigator.userAgent + "-->\n" + $("#content").html();
			$("#tosave").val(postData);
			return;
		} else {
			event.preventDefault();
		}

	});
	$("#switchstyle").change(function() {
		if ($(this).is(":checked")) {
			$('#style[rel=stylesheet]').attr("href", "css/darkstyle.css");
		} else {
			$('#style[rel=stylesheet]').attr("href", "css/style.css");
		}
	});
	$("#menusw").buttonset();

	$("#menusw").change(function() {
		if ($("#ms1").is(":checked")) {
			$("#side-menu").fancytree("getTree").reload({
				url: '/stor2rrd-cgi/genjson.sh?jsontype=menu'
			});
		} else {
			$("#side-menu").fancytree("getTree").reload({
				url: '/stor2rrd-cgi/genjson.sh?jsontype=menuh'
			});
		}
	});

	setInterval(function () {
		checkStatus();
	}, 600000);
});

function imgPaths() {
	$('#content img').each(function() { /* subpage without tabs */
		var imgsrc = $(this).attr("src");
		if (/loading\.gif$/.test(imgsrc)) {
			$(this).attr("src", 'css/images/sloading.gif');
		} else if (!/\//.test(imgsrc)) {
			var n = $('#side-menu').fancytree('getActiveNode');
			var url = n.data.href;

			$(this).attr("src", url.substr(0, url.lastIndexOf('/') + 1) + imgsrc);
		}
	});
}

function autoRefresh() {
	if (timeoutHandle) {
		clearTimeout(timeoutHandle);
	}
	timeoutHandle = setTimeout(function() {
		$("#side-menu").fancytree("getTree").reactivate();
		autoRefresh();
	}, 600000); /* 600000 = 10 minutes */
}

/********* Execute after new content load */

function myreadyFunc() {

	loaded = 0;
	var dbHashes = $.cookie('dbHashes');
	$("div.zoom").uniqueId();

	if (!dbHashes) {
		dbHash = [];
	} else {
		dbHash = dbHashes.split(":");
		$.each(dbHash, function(index, value) {
			if (value.length == 9) {
				dbHash[index] = value.substr(0, 7) + "x" + value.substr(7);
			}
		});
	}

	$('#tabs').tabs({
		active: curTab,
		beforeLoad: function( event, ui ) {
			ui.panel.html('<img src="css/images/sloading.gif" style="display: block; margin-left: auto; margin-right: auto; margin-top: 10em" />');
		},
		activate: function(event, ui) {
			curTab = ui.newTab.index();
			var tabName = "";
			if ($("#tabs").length) {
				tabName = " [" + $('#tabs li.ui-tabs-active').text() + "]";
			}
			if (curNode) {
				if (curNode.data.hash) {
					urlMenu = curNode.data.hash;
				} else {
					urlMenu = curNode.key.substring(1);
				}
				History.pushState({
					menu: curNode.key,
					tab: curTab
				}, "STOR2RRD - " + $("#title").text() + tabName, '?menu=' + curNode.key.substring(1) + "&tab=" + curTab);
			}
			setTitle(curNode);

			if ($("#emptydash").length) {
				$("ul.dashlist").empty();
				genDashboard();
				autoRefresh();
			} else {
				autoRefresh();
				loadImages(ui.newPanel.selector + " img.lazy");
				hrefHandler();
				dataSource();
				showHideSwitch();
				sections();
			}
		},
		load: function(event, ui) {
			hrefHandler();
			var $t = ui.panel.find('table.tablesorter');
			if ($t.length) {
				tableSorter($t);
			}
		}
	});

	setTimeout(function() {
		if ($("#tabs").length) {
			loadImages("div[aria-hidden=false] img.lazy");
		} else {
			loadImages('#content img.lazy');
		}
		dataSource();
	}, 100);

	$("table.tablesorter").each(function() {
		tableSorter(this);
	});

	hrefHandler();

	$("#subheader fieldset").hide();

	$("#nmonsw").buttonset();

	$("#nmonsw").click(function() {
		sections();
		var newTabHref = '';
		var activeTab = $('#tabs li.ui-tabs-active.tabfrontend,#tabs li.ui-tabs-active.tabbackend').text();
		showHideSwitch();
		if (activeTab) {
			if ($("#nmr1").is(':checked')) {
				newTabHref = $('#tabs li.tabfrontend a:contains("' + activeTab + '")').attr("href");
			} else {
				newTabHref = $('#tabs li.tabbackend a:contains("' + activeTab + '")').attr("href");
			}
			$("[href='" + newTabHref + "']").trigger("click");
		}
	});

	if ( $("#histrep").length ) {
		var checkedBoxes = $.cookie('HistFormCheckBoxes');
		if ( !checkedBoxes ) {
			// Set basic set of output data if not defined
			checkedBoxes = ["io_rate", "read_io", "write_io", "data_rate", "read", "write"];
		}
		$.each(checkedBoxes, function(index, value) {
			$( "input:checkbox[value=" + value + "]" ).prop('checked', true);
		});
	}

	$("#radio").buttonset();
	$("#radiosrc").buttonset();

	$("input[type=checkbox][name=lparset]").change(function() {
		if ($("#radios2").is(':checked')) {
			$("#lpartree").fancytree("getTree").reload({
				url: '/stor2rrd-cgi/genjson.sh?jsontype=hmcsel'
			});
			$("#lparfieldset legend").text("HMC | Server | LPAR");
		} else {
			$("#lpartree").fancytree("getTree").reload({
				url: '/stor2rrd-cgi/genjson.sh?jsontype=lparsel'
			});
			$("#lparfieldset legend").text("Server | LPAR");
		}
	});

	fancyBox();

	function fancyBox() {
		$('a.detail').fancybox({
			type: 'image',
			// transitionIn: 'none',
			// transitionOut: 'none',
			live: false,
			speedIn: 400,
			speedOut: 100,
			autoScale: false, // images won't be scaled to fit to browser's height
			overlay: {
				showEarly: false,
				css: {
					'background': 'rgba(58, 42, 45, 0.95)'
				}
			},
			hideOnContentClick: true,
			onStart: function(obj) {
				if (storedUrl) {
					obj.href = zoomedUrl;
				} else {
					var tUrl = obj.href;
					tUrl += "&none=" + Math.floor(new Date().getTime() / 1000);
					obj.href = tUrl;
				}
				return true;
			},
			onClosed: function() {
				if (storedUrl) {
					$(storedObj).attr("href", storedUrl);
					storedUrl = "";
					storedObj = {};
				}
			}
		});
	}

	var now = new Date();
	var twoWeeksBefore = new Date();
	var yesterday = new Date();
	var nowPlusHour = new Date();
	yesterday.setDate(now.getDate() - 1);
	twoWeeksBefore.setDate(now.getDate() - 14);
	nowPlusHour.setHours(now.getHours() + 1);


	var startDateTextBox = $('#fromTime');
	var endDateTextBox = $('#toTime');

	$("#fromTime").datetimepicker({
		defaultDate: '-1d',
		dateFormat: "yy-mm-dd",
		timeFormat: "HH:00",
		maxDate: nowPlusHour,
		changeMonth: true,
		changeYear: true,
		showButtonPanel: true,
		showMinute: false,
		onClose: function(dateText, inst) {
			if (endDateTextBox.val() !== '') {
				var testStartDate = startDateTextBox.datetimepicker('getDate');
				var testEndDate = endDateTextBox.datetimepicker('getDate');
				if (testStartDate > testEndDate) {
					endDateTextBox.datetimepicker('setDate', testStartDate);
				}
			} else {
				endDateTextBox.val(dateText);
			}
		},
		onSelect: function(selectedDateTime) {
			endDateTextBox.datetimepicker('option', 'minDate', startDateTextBox.datetimepicker('getDate'));
		}
	});
	if ($("#fromTime").length) {
		var fromTime = $.cookie('fromTimeField');
		if ( fromTime ) {
			$("#fromTime").datetimepicker("setDate", fromTime);
		} else {
			$("#fromTime").datetimepicker("setDate", yesterday);
		}
	}

	$("#toTime").datetimepicker({
		defaultDate: 0,
		dateFormat: "yy-mm-dd",
		timeFormat: "HH:00",
		maxDate: nowPlusHour,
		changeMonth: true,
		changeYear: true,
		showButtonPanel: true,
		showMinute: false,
		onClose: function(dateText, inst) {
			if (startDateTextBox.val() !== '') {
				var testStartDate = startDateTextBox.datetimepicker('getDate');
				var testEndDate = endDateTextBox.datetimepicker('getDate');
				if (testStartDate > testEndDate) {
					startDateTextBox.datetimepicker('setDate', testEndDate);
				}
			} else {
				startDateTextBox.val(dateText);
			}
		},
		onSelect: function(selectedDateTime) {
			startDateTextBox.datetimepicker('option', 'maxDate', endDateTextBox.datetimepicker('getDate'));
		}
	});
	if ($("#toTime").length) {
		var toTime = $.cookie('toTimeField');
		if ( toTime ) {
			$("#toTime").datetimepicker("setDate", toTime);
		} else {
			$("#toTime").datetimepicker("setDate", now);
		}
	}

	// History reports form submit
	$("#histrep").submit(function(event) {
		var outputDataCount = $( "input:checked[name=output]" ).length;
		if (!outputDataCount) {
			alert("Please select at least one data output for report!");
			return false;
		}

		var $poolTree = $("#pooltree").fancytree("getTree");
		var $portTree = $("#porttree").fancytree("getTree");
		var $rankTree = $("#ranktree").fancytree("getTree");
		var $voluTree = $("#voltree").fancytree("getTree");

		var selCount = 0;
		var pota, prta, rata, vota;

		if ($poolTree.length !== 0) {
			selCount += $poolTree.getSelectedNodes().length;
			$poolTree.generateFormElements(true, false, false);
			pota = 'ft_' + $poolTree._id + "[]";
		}
		if ($portTree.length !== 0) {
			selCount += $portTree.getSelectedNodes().length;
			$portTree.generateFormElements(true, false, false);
			prta = 'ft_' + $portTree._id + "[]";
		}
		if ($rankTree.length !== 0) {
			selCount += $rankTree.getSelectedNodes().length;
			$rankTree.generateFormElements(true, false, false);
			rata = 'ft_' + $rankTree._id + "[]";
		}
		if ($voluTree.length !== 0) {
			selCount += $voluTree.getSelectedNodes().length;
			$voluTree.generateFormElements(true, false, false);
			vota = 'ft_' + $voluTree._id + "[]";
		}

		if ( selCount === 0) {
			alert("Please select at least one item for report");
			return false;
		}

		var fromDate = $("#fromTime").datetimepicker("getDate");
		var toDate = $("#toTime").datetimepicker("getDate");

		$.cookie('fromTimeField', fromDate, {
            expires: 0.04
        });
		$.cookie('toTimeField', toDate, {
            expires: 0.04
        });

		$("#start-hour").val(fromDate.getHours());
		$("#start-day").val(fromDate.getDate());
		$("#start-mon").val(fromDate.getMonth() + 1);
		$("#start-yr").val(fromDate.getFullYear());

		$("#end-hour").val(toDate.getHours());
		$("#end-day").val(toDate.getDate());
		$("#end-mon").val(toDate.getMonth() + 1);
		$("#end-yr").val(toDate.getFullYear());

		// get HMC & server name from menu url
		// var serverPath = $("#side-menu").fancytree('getActiveNode').data.href.split('/');
		var storage = curNode.parent.title;
		$("#storage").val(storage);

		var checkedBoxes = $("input:checkbox:checked.allcheck, input:checkbox:checked[name=output]").map(function () {
			return this.value;
		}).get();
		$.cookie('HistFormCheckBoxes',checkedBoxes, {
			expires: 60
		});

		// exclude allcheck boxes
		$(this).find(":checkbox.allcheck").attr("disabled", true);

		// remove parent items if whole branch checked
		var postArray = $(this).serializeArray();
		for (var i = 0; i < postArray.length; i++) {
			if (postArray[i].value.indexOf('_') === 0) {
				postArray.splice(i, 1);
				i--;
			}
		}
		// replace fancytree fieldnames ft_...
		$.each(postArray, function(index, value) {
			if (value.name == pota) {
				value.name = 'POOL';
			} else if (value.name == prta) {
				value.name = 'PORT';
			} else if (value.name == rata) {
				value.name = 'RANK';
			} else if (value.name == vota) {
				value.name = 'VOLUME';
			}
		});
		var postData = $.param(postArray);

		if (sysInfo.guidebug == 1) {
			copyToClipboard(postData);
			// alert("POST data:\n" + postData);
		}

		$('#content').load(this.action, postArray, function() {
			if (curNode.data.hash) {
				urlMenu = curNode.data.hash;
			} else {
				urlMenu = curNode.key.substring(1);
			}
			History.pushState({
				menu: curNode.key,
				tab: curTab,
				form: "hrep"
			}, "STOR2RRD - " + $('#title').text(), '?menu=' + curNode.key.substring(1) + "&tab=" + curTab + "&form=");
			imgPaths();
			myreadyFunc();
			saveData("hrep"); // save when page loads
		});
		event.preventDefault();
		if (timeoutHandle) {
			clearTimeout(timeoutHandle);
		}
	});

	//*************** Remove unwanted parent classes
	$('#content table.tabsyscfg').has('table').removeClass('tabsyscfg');
	$('#content table.tabtop10').has('table').removeClass('tabtop10');

	showHideSwitch();

	if (navigator.userAgent.indexOf('MSIE 8.0') < 0) {
		$('#content a:not(.nowrap):contains("How it works")').wrap(function() {
			var url = this.href;
			return "<div id='hiw'><a href='" + url + "' target='_blank'><img src='css/images/help-browser.gif' alt='How it works?' title='How it works?'></a></div>";
		});
	}

	$("#datasrc").click(function() {
		$("#data-src-info").dialog("open");
	});

	$("#pooltree").fancytree({
		extensions: ["persist"],
		persist: {
			cookiePrefix: "pooltree-"
		},
		clickFolderMode: 2,
		checkbox: true,
		selectMode: 2,
		/* init: function (){
$(this).fancytree("option", "selectMode", 3);
$(this).fancytree("getTree").getFirstChild().fixSelection3FromEndNodes();
},
*/
		icons: false,
		autoCollapse: true,
		source: {
			url: '/stor2rrd-cgi/genjson.sh?' + histRepQueryString('POOL')
		}
	});
	$("#srvlparfilter").keyup(function(e){
		var n,
			match = $(this).val();
		var $ltree = $("#voltree").fancytree("getTree");

		if (e && e.which === $.ui.keyCode.ESCAPE || $.trim(match) === "") {
			$ltree.clearFilter();
			return;
		}
		n = $ltree.filterNodes(function (node) {
			return new RegExp(match, "i").test(node.title);
		}, true);
		$ltree.visit(function(node){
			if (!$(node.span).hasClass("fancytree-hide")) {
				node.setExpanded(true);
			}
		});
	}).focus();
	$("#porttree").fancytree({
		extensions: ["persist"],
		persist: {
			cookiePrefix: "porttree-"
		},
		clickFolderMode: 2,
		checkbox: true,
		selectMode: 2,
		icons: false,
		autoCollapse: true,
		source: {
			url: '/stor2rrd-cgi/genjson.sh?' + histRepQueryString('PORT')
		}
	});

	$("#ranktree").fancytree({
		extensions: ["persist"],
		persist: {
			cookiePrefix: "ranktree-"
		},
		clickFolderMode: 2,
		checkbox: true,
		selectMode: 2,
		icons: false,
		autoCollapse: true,
		source: {
			url: '/stor2rrd-cgi/genjson.sh?' + histRepQueryString('RANK')
		}
	});

	$("#voltree").fancytree({
		extensions: ["persist", "filter"],
		persist: {
			cookiePrefix: "voltree-"
		},
		filter: {
			mode: "hide",
			autoApply: true
		},
		clickFolderMode: 2,
		checkbox: true,
		selectMode: 2,
		icons: false,
		autoCollapse: true,
		source: {
			url: '/stor2rrd-cgi/genjson.sh?' + histRepQueryString('VOLUME')
		}
	});

	$("div.favs").each(function() {
		var url = $(this).parent().find('a.detail').attr('href');
		var urlObj = itemDetails(url, true);
		var hash = "";
		if (urlObj.type == "NODE-CACHE") {
			urlObj.type = "CACHE";
		}
		if (urlObj.host == "totals" && urlObj.name == "totals") {
			hash = "Totals" + curNode.title + 'SubSys_SUM';
		} else if (curNode.data.agg) {
			hash = urlObj.host + urlObj.type + 'SubSys_SUM';
		} else if (urlObj.host == "custom-group") {
			hash = "nana" + curNode.title;
		} else if (urlObj.item.substring(0, 4) == "san_") {
			hash = urlObj.host + urlObj.type + (curNode.data.altname ? curNode.data.altname : curNode.title);
		} else {
			hash = urlObj.host + urlObj.type + curNode.data.altname;
		}

		hash = hex_md5(hash).substring(0, 7);
		hash = hash + urlObj.itemcode + urlObj.time;
		$(this).data("gid", hash);

		if ($.inArray(hash, dbHash) >= 0) {
			$(this).removeClass("favoff"); /* Add item */
			$(this).addClass("favon");
			$(this).attr("title", "Remove this graph from Dashboard");
		} else {
			$(this).removeClass("favon");
			$(this).addClass("favoff");
			$(this).attr("title", "Add this graph to Dashboard");
		}
	});

	$("div.popdetail").each(function() {
		$(this).attr("title", "Click to show detail");
	});

	$("div.popdetail").click(function() {
		$(this).siblings("a").click();
	});

	$("div.favs").click(function() {
		var hash = $(this).data("gid");
		if ($(this).hasClass("favon")) { /* Remove item */
			$(this).removeClass("favon");
			$(this).addClass("favoff");
			$(this).attr("title", "Add this graph to Dashboard");
			var toRemove = $.inArray(hash, dbHash);
			if (toRemove >= 0) {
				dbHash.splice(toRemove, 1);
				saveCookies();
			}
		} else {
			$(this).removeClass("favoff"); /* Add item */
			$(this).addClass("favon");
			$(this).attr("title", "Remove this graph from Dashboard");
			dbHash.push(hash);
			saveCookies();
		}
	});

	function saveCookies() {
		var hashes = dbHash.join(":");
		$.cookie('dbHashes', hashes, {
			expires: 60
		});
	}


	if (!areCookiesEnabled()) {
		$("#nocookies").show();
	} else {
		$("#nocookies").hide();
		if (dbHash.length === 0) {
			$("#emptydash").show();
		} else {
			$("#emptydash").hide();
		}
	}

	if ($("#emptydash").length) {
		$( "#tabs > ul li" ).hide();
		genDashboard();
	}

	function genDashboard() {
		if (sysInfo.vmImage) {
			$( "#lpar2rrd" ).attr("onclick", "window.location.href = '/lpar2rrd'");
		}
		if (prodName == "STOR2RRD") {
			$( "#lpar2rrd" ).show()
		}
		if ($.cookie('flatDB')) {
			$( "#tabs" ).tabs( "destroy" );
			$( "#tabs > ul" ).hide();
			$( "#tabs div" ).hide();
			$( ".dashlist p" ).show();
		}
		if (dbHash.length) {
			$.each(dbHash, function(i, val) {
				var dbItem = hashRestore(val);
				if (jQuery.isEmptyObject(dbItem)) {
					return true;
				}
				var isSAN = (dbItem.item.substring(0, 4) == "san_");
				if (dbItem.server == 'CACHE') {
					dbItem.server = "NODE-CACHE";
				}

				if (dbItem.lpar == 'sum' && ! isSAN) {
					dbItem.lpar = dbItem.item;
					dbItem.item = 'sum';
				} else if (isSAN) {
					if (dbItem.host == "Totals") {
						dbItem.host = "totals";
						// dbItem.item = dbItem.lpar;
						dbItem.lpar = "totals";
					}
				}

				var complHref = urlQstring(dbItem, 1) + "&none=" + Math.floor(new Date().getTime() / 1000);
				var complUrl = urlQstring(dbItem, 2) + "&none=" + Math.floor(new Date().getTime() / 1000);
				var title = dbItem.host + ": ";
				if (dbItem.item == "sum") {
					if (dbItem.longname) {
						dbItem.host = dbItem.longname;
					}
					title += urlItems[dbItem.lpar][0] + " | ";
				} else {
					if (dbItem.longname) {
						dbItem.lpar = dbItem.longname;
					}
					var lparstr = dbItem.lpar;
					if (lparstr) {
						title += lparstr + ": " + urlItems[dbItem.item][0] + " | ";
					}
				}

				title += intervals[dbItem.time];

				var topTitle = dbItem.host;

				if (dbItem.host == "custom-group") {
					topTitle = dbItem.lpar;
				}

				var flat = $.cookie('flatDB');

				if (dbItem.item) {
					if (dbItem.item.indexOf("custom") >= 0) {
						$( "#tabs > ul li:eq( 0 )" ).show();
						if (flat) {
							$( "#tabs-1" ).show();
						}
						$("#dashboard-cust").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (isSAN) {
						$( "#tabs > ul li:eq( 8 )" ).show();
						if (flat) {
							$( "#tabs-9" ).show();
						}
						$("#dashboard-san").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == 'POOL') {
						$( "#tabs > ul li:eq( 1 )" ).show();
						if (flat) {
							$( "#tabs-2" ).show();
						}
						$("#dashboard-pool").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "RANK" || dbItem.server == "Managed disk") {
						$( "#tabs > ul li:eq( 2 )" ).show();
						if (flat) {
							$( "#tabs-3" ).show();
						}
						$("#dashboard-rank").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "VOLUME") {
						$( "#tabs > ul li:eq( 3 )" ).show();
						if (flat) {
							$( "#tabs-4" ).show();
						}
						$("#dashboard-volume").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "DRIVE") {
						$( "#tabs > ul li:eq( 4 )" ).show();
						if (flat) {
							$( "#tabs-5" ).show();
						}
						$("#dashboard-drive").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "PORT") {
						$( "#tabs > ul li:eq( 5 )" ).show();
						if (flat) {
							$( "#tabs-6" ).show();
						}
						$("#dashboard-port").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "CPU-NODE" || dbItem.server == "CPU util") {
						$( "#tabs > ul li:eq( 6 )" ).show();
						if (flat) {
							$( "#tabs-7" ).show();
						}
						$("#dashboard-cpu").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "HOST") {
						$( "#tabs > ul li:eq( 7 )" ).show();
						if (flat) {
							$( "#tabs-8" ).show();
						}
						$("#dashboard-host").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "SAN") {
						$( "#tabs > ul li:eq( 8 )" ).show();
						if (flat) {
							$( "#tabs-9" ).show();
						}
						$("#dashboard-san").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					} else if (dbItem.server == "NODE-CACHE") {
						$( "#tabs > ul li:eq( 9 )" ).show();
						if (flat) {
							$( "#tabs-10" ).show();
						}
						$("#dashboard-cache").append("<li><a href='" + complHref + "' class='detail'><span class='dbitemtitle'>" + topTitle + "</span></br><img class='lazy' src='css/images/sloading.gif' data-src='" + complUrl + "' title='" + title + "' alt='" + val + "'></a><div class='dash' title='Remove this item from DashBoard'></div></li>");
					}
				}
			});

			if ( $("#tabs > ul li:visible").length == 1) {
				$("#tabs > ul li:visible a").click();
			}

			$(".dashlist li").css({
				"width": Number(sysInfo.dashb_rrdwidth) + 75 + "px",
				"height": Number(sysInfo.dashb_rrdheight) + 60 + "px"
			//	"line-height": Number(sysInfo.dashb_rrdheight) + 60 + "px"
			});
			loadImages('#content img.lazy');
			fancyBox();

			$("div.dash").click(function() {
				var hash = $(this).parent().find('img').attr('alt');
				var toRemove = $.inArray(hash, dbHash);
				if (toRemove >= 0) {
					dbHash.splice(toRemove, 1);
					saveCookies();
					$(this).parent().hide("slow");
				}
			});
			$("ul.dashlist").sortable({
				dropOnEmpty: false
			});

			$("ul.dashlist").on("sortupdate", function(event, ui) {
				dbHash.length = 0;
				$("ul.dashlist li").find('img').each(function() {
					var hash = $(this).attr('alt');
					dbHash.push(hash);
				});
				saveCookies();
			});
		}
	}

	$("#dashfooter button").button();

	if ($.cookie('flatDB')) {
		$( "#dbstyle" ).button({ label: "Switch to Tabbed Style" });
	}

	$("#clrcookies").click(function() {
		var conf = confirm("Are you sure you want to remove all DashBoard items?");
		if (conf === true) {
			dbHash.length = 0;
			saveCookies();
			$("#side-menu").fancytree("getTree").reactivate();
		}
	});
	$("#wipecookies").button().click(function() {
		var conf = confirm("Are you sure you want to wipe all STOR2RRD cookies for this host.domain/path?");
		if (conf === true) {
			for (var it in $.cookie()) {
				$.removeCookie(it);
			}
		}
	});
	$("#envdump").button().click(function() {
		$.get("/stor2rrd-cgi/genjson.sh?jsontype=test", function(data) {
			alert(data);
		});
	});

	$("#filldash").click(function() {
		var conf = confirm("This will append predefined items: POOL IO R/W summary. Are you sure?");
		if (conf === true) {
			$.getJSON("/stor2rrd-cgi/genjson.sh?jsontype=pre", function(data) {
				$.each(data, function(key, val) {
					if ($.inArray(val, dbHash) < 0) {
						dbHash.push(val);
					}
				});
				saveCookies();
				$("#side-menu").fancytree("getTree").reactivate();
			});
		}
	});
	$("#filldashlink").click(function(event) {
		event.preventDefault();
		$("#filldash").click();
	});

	$( "#dbstyle" ).click(function() {
		if ($.cookie('flatDB')) {
			$.removeCookie('flatDB');
		} else {
			$.cookie('flatDB', true, {
				expires: 365
			});
		}
		$("#side-menu").fancytree("getTree").reactivate();
	});

	$("ul.ui-tabs-nav").hover(function() {
		if (!$("#emptydash").length) {
			$("#tabgroups").fadeIn(200);
		}
	}, function() {
		$("#tabgroups").fadeOut(100);
	});

	$('form[action="/stor2rrd-cgi/acc-wrapper.sh"]').submit(function(event) {
		event.preventDefault();
		if (timeoutHandle) {
			clearTimeout(timeoutHandle);
		}
		$('#content').empty();

		$('#content').append("<div style='width: 100%; height: 100%; text-align: center'><img src='css/images/sloading.gif' style='margin-top: 200px'></div>");
		// $('#title').text("Accounting results");
		var postData = $(this).serialize() + "&Report=Generate+Report";
		if (sysInfo.guidebug == 1) {
			copyToClipboard(postData);
		}
		$('#content').load(this.action, postData, function() {
			imgPaths();
			myreadyFunc();
		});
	});

	$( "input.allcheck" ).click(function() {
		var isChecked = this.checked;
		if ( this.name == "outdata" ) {
			$( "input:checkbox[name=output]" ).prop('checked', isChecked);
		} else {
			$( "#" + this.name + "tree").fancytree("getTree").visit(function(node) {
			if (!node.hasChildren()) {
				if (!$(node.span).hasClass("fancytree-hide")) {
					node.setSelected(isChecked);
				}
			}
			});
		}
	});
	$("#alrttree").fancytree({
		icons: false,
		clickFolderMode: 1,
		autoCollapse: false,
		create: function () {
			if (timeoutHandle) {
				clearTimeout(timeoutHandle);
			}
			$.getJSON( "/stor2rrd-cgi/genjson.sh?jsontype=alrtgrptree", function( data ) {
				mailGroups = data;
			});
			$.getJSON( "/stor2rrd-cgi/genjson.sh?jsontype=fleet", function( data ) {
				fleet = data;
			});
		},
		init: function () {
			loaded += 1;
			if (loaded > 1) {
				$(".savealrtcfg").button().prop( "disabled", false);
			}
		},
		extensions: ["persist", "edit", "table", "gridnav"],
		source: {
			url: '/stor2rrd-cgi/genjson.sh?jsontype=alrttree'
		},
		renderColumns: function(event, data) {
			var node = data.node,
			$select = $("<select class='alrtcol' name='metric' />"),
			$tdList = $(node.tr).find(">td"),
			selItems = ['io','read_io','write_io','data','read','write'];
			if( node.getLevel() == 3 ) {
				var storType = fleet[node.parent.parent.title] && fleet[node.parent.parent.title]['STORTYPE'];
				if (storType == "DS5K") {
					selItems = ['io','data'];
				}
				$.each(selItems, function(i, val) {
					$("<option />", {text: val , value: val, selected: (node.data.metric == val)}).appendTo($select);
				});
				// (index #0 is rendered by fancytree by adding the checkbox)
				// (index #2 is rendered by fancytree)
				$tdList.eq(3).html($select);
				var err = node.data.limit ? "" : " ui-state-error";
				$tdList.eq(4).html("<input type='text' size='5' class='alrtcol" +  err + "' name='limit' value='" + node.data.limit + "'>");
				$tdList.eq(5).html("<input type='text' size='5' class='alrtcol' name='peak' value='" + node.data.peak + "'>");
				$tdList.eq(6).html("<input type='text' size='5' class='alrtcol' name='repeat' value='" + node.data.repeat + "'>");
				$tdList.eq(7).html("<input type='text' size='5' class='alrtcol' name='exclude' value='" + node.data.exclude + "'>");
				$select = $("<select class='alrtcol' name='mailgrp' />"),
				$("<option />", {text: "---" , value: "", selected: true}).appendTo($select);
				$.each(mailGroups, function(i, val) {
					$("<option />", {text: val.title, value: val.title, selected: (node.data.mailgrp == val.title)}).appendTo($select);
				});
				$tdList.eq(8).html($select);
				$tdList.eq(9).html("<button class='removeme' title='Remove rule'>X</button>");
			}
		},
		table: {
			indentation: 20,
			nodeColumnIdx: 2,
			checkboxColumnIdx: 0
		},
		gridnav: {
			autofocusInput: false,
			handleCursorKeys: true
		}
	});

	// Set FT data to currently selected option
	$( "#alrttree" ).on('change', "select.alrtcol", function(event, data) {
		$.ui.fancytree.getNode(event.target).data[event.target.name] = event.target.value;
	});
	$( "#alrttree" ).on('click', "select.alrtcol", function(event, data) {
		event.stopPropagation();
	});
	$( "#alrttree" ).on('blur', "input.alrtcol", function(event, data) {
		var valid = false;

		switch (event.target.name) {
			case "limit":
				valid = event.target.value.match(/^[0-9]+$/);
				// checkRegexp( event.target.value, /[0-9]*/, "This doesn't look like valid e-mail address" );
			break;
			case "peak":
				valid = event.target.value.match(/^[0-9]*$/);
				if (event.target.value && (event.target.value < 5)) {
					event.target.value = 5;
				}
				if (event.target.value && (event.target.value > 120)) {
					event.target.value = 120;
				}
			break;
			case "repeat":
				valid = event.target.value.match(/^[0-9]*$/);
				if (event.target.value && (event.target.value < 5)) {
					event.target.value = 5;
				}
				if (event.target.value && (event.target.value > 168)) {
					event.target.value = 168;
				}
			break;
			case "exclude":
				valid = (event.target.value == "") || event.target.value.match(/^([01]?[0-9]|^2[0-4])\-([01]?[0-9]|2[0-4])$/);
			break;
		}
		if (valid) {
			$.ui.fancytree.getNode(event.target).data[event.target.name] = event.target.value;
			$(event.target).removeClass( "ui-state-error" );
		} else {
			event.target.focus();
			$(event.target).addClass( "ui-state-error" );
		}
	});

	$( "#optform" ).on('blur', "input.alrtoption", function(event, data) {
		var valid = false;
		switch (event.target.name) {
			case "NAGIOS":
				valid = event.target.value.match(/^[01]$/);
				// checkRegexp( event.target.value, /[0-9]*/, "This doesn't look like valid e-mail address" );
			break;
			case "EXTERN_ALERT":
				valid = (event.target.value == "") || event.target.value.match(/^bin\/.+$/);
				// checkRegexp( event.target.value, /[0-9]*/, "This doesn't look like valid e-mail address" );
			break;
			case "EMAIL_GRAPH":
				valid = event.target.value.match(/^[0-9]*$/);
				if (event.target.value && (event.target.value > 256)) {
					event.target.value = 256;
				}
			break;
			case "REPEAT_DEFAULT":
				valid = event.target.value.match(/^[0-9]*$/);
				if (event.target.value && (event.target.value < 5)) {
					event.target.value = 5;
				}
				if (event.target.value && (event.target.value > 168)) {
					event.target.value = 168;
				}
			break;
			case "PEAK_TIME_DEFAULT":
				valid = event.target.value.match(/^[0-9]*$/);
				if (event.target.value && (event.target.value < 5)) {
					event.target.value = 5;
				}
				if (event.target.value && (event.target.value > 120)) {
					event.target.value = 120;
				}
			break;
		}
		if (valid) {
			$(event.target).removeClass( "ui-state-error" );
		} else {
			event.target.focus();
			$(event.target).addClass( "ui-state-error" );
		}
	});

	$( "#alrttree,#alrtgrptree" ).on('click', "button.removeme", function(event, data) {
		$.ui.fancytree.getNode(event.target).remove();
		mailGroups = $("#alrtgrptree").fancytree("getTree").toDict();
	});
	$( "#addnewalrt" ).on( "click", function() {
		if (mailGroups) {
			var node = $( "#alrttree").fancytree("getTree").getActiveNode();
			if (! node) {
				var node = $( "#alrttree").fancytree("getTree").getRootNode();
			}
			params = {};
			if (node.getLevel() == 1) {
				params.storage = node.title;
			} else if (node.getLevel() == 2) {
				params.storage = node.parent.title;
				params.volume = node.title;
			} else if (node.getLevel() == 3) {
				params.storage = node.parent.parent.title;
				params.volume = node.parent.title;
			}

			addNewAlrtForm("Create new alerting rule", params);
		} else {
			$.alert("You have no E-mail groups defined, please create some first!", "Add new alert rule result", false);
		}
	});

	$("#alrtgrptree").fancytree({
		icons: false,
		clickFolderMode: 1,
		autoCollapse: false,
		extensions: ["persist", "edit", "table", "gridnav"],
		source: {
			url: '/stor2rrd-cgi/genjson.sh?jsontype=alrtgrptree'
		},
		init: function () {
			loaded += 1;
			if (loaded > 1) {
				$(".savealrtcfg").button().prop( "disabled", false);
			}
		},
		renderColumns: function(event, data) {
			var node = data.node,
			$tdList = $(node.tr).find(">td");
			// (index #0 is rendered by fancytree by adding the checkbox)
			// (index #2 is rendered by fancytree)
			$tdList.eq(1).text(node.data.email);
			$tdList.eq(3).html("<button class='removeme' title='Remove line'>X</button>");
		},
		table: {
			indentation: 20,
			nodeColumnIdx: 2,
			checkboxColumnIdx: 0
		},
		gridnav: {
			autofocusInput: false,
			handleCursorKeys: true
		}
	});
	$( "#addalrtgrp" ).on( "click", function() {
		var node = $( "#alrtgrptree").fancytree("getTree").getActiveNode();
		if (! node) {
			var node = $( "#alrtgrptree").fancytree("getTree").getRootNode();
		}
		params = {};
		if (node.getLevel() == 1) {
			params.storage = node.title;
		} else if (node.getLevel() == 2) {
			params.storage = node.parent.title;
			params.volume = node.title;
		}
		addNewAgrpForm("Create new mail group", params);
	});
	$("#alrttimetree").fancytree({
		checkbox: false,
		icons: false,
		clickFolderMode: 2,
		selectMode: 3, // 1:single, 2:multi, 3:multi-hier
		autoCollapse: false,
		source: {
			url: '/stor2rrd-cgi/genjson.sh?jsontype=alrttimetree'
		}
	});
	$( "#optform" ).load(function() {
		$.getJSON( "/stor2rrd-cgi/genjson.sh?jsontype=alrtcfg", function( data ) {
			alrtCfg = data;
		});
	});

	$("#cgtree").fancytree({
		icons: false,
		// autoCollapse: true,
		clickFolderMode: 1,
		titlesTabbable: true,     // Add all node titles to TAB chain
		quicksearch: true,        // Jump to nodes when pressing first character
		source: {url: '/stor2rrd-cgi/genjson.sh?jsontype=custgrps'},

		// extensions: ["edit", "table", "gridnav"],
		extensions: ["persist", "edit", "table", "gridnav"],

		create: function() {
			$.getJSON( "/stor2rrd-cgi/genjson.sh?jsontype=fleet", function( data ) {
				fleet = data;
			});
			if (timeoutHandle) {
				clearTimeout(timeoutHandle);
			}
			$("#addcgrp").click(function () {
				var child = {
					"title": "",
					"folder": true,
					"expanded": true,
					"children": [{
						"expanded": true,
						"folder": true,
						"title": ".*",
						"children": [{
							"title": ".*"
						}]
					}]
				};
				if ($("#cgtree").fancytree("getRootNode").getFirstChild()) {
					$("#cgtree").fancytree("getRootNode").getFirstChild().editCreateNode("before", child);
				} else {
					$("#cgtree").fancytree("getRootNode").editCreateNode("child", child);
				}
			});

		},

		edit: {
			triggerStart: ["f2", "dblclick", "shift+click", "mac+enter"],
			edit: function(event, data) {
				switch (data.node.getLevel()) {
				case 1:
					data.input.attr("placeholder", "Type group name");
					break;
				case 2:
					data.input.attr("placeholder", "Type storage name");
					break;
				case 3:
					data.input.attr("placeholder", "Type " + data.node.parent.parent.data.type + " name");
					break;
				default:
				}
				if (data.node.getLevel() == 2) {
					var acData = Object.keys(fleet);
					data.input.autocomplete({
						autoFocus: false,
						source: acData,
						select: function( event, ui ) {
							// data.input.value =
							console.log(ui);
						},
						focus: function( event, ui ) {
							data.input.val( ui.item.value );
						}
					});
				} else if (data.node.getLevel() == 3) {
					var acData = [];
					var type = data.node.parent.parent.data.type;
					jQuery.each(fleet, function(i, val) {
						var re = new RegExp("^" + data.node.parent.title + "$", "");
						if (re.test(i)) {
							if (fleet[i][type]) {
								$.merge(acData, fleet[i][type]);
							}
						}
					});

					// var acData = fleet[data.node.parent.title][data.node.parent.parent.data.type];
					acData = jQuery.unique( acData );
					data.input.autocomplete({
						autoFocus: false,
						source: acData,
						focus: function( event, ui ) {
							data.input.val( ui.item.value );
						}
					});
				}
			},
			beforeClose: function(event, data) {
				if (data.input.autocomplete("instance")) {
					data.input.autocomplete("close");
				}
				if (data.save) {
					try {
						var re = new RegExp(data.input.val(), "");
					} catch(exception) {
						return true;
					}
					if (data.isNew) {
						if (data.node.getLevel() == 1) {
							data.node.data.type = "VOLUME";
						}
					}
				}
			},
			close: function (event, data) {
					// Editor was removed.
					// data.node.render();
					if (data.node && data.node.getLevel() != 3) {
						data.node.folder = true;
					}
					data.node && $(data.node.tr).find("button").click();
				}
				// triggerStart: ["f2", "shift+click", "mac+enter"],
				// close: function(event, data) {
				//	if( data.save && data.isNew ){
				//	// Quick-enter: add new nodes until we hit [enter] on an empty title
				//	$("#cgtree").trigger("nodeCommand", {cmd: "addSibling"});
				//	}
				// }
		},
		table: {
			indentation: 20,
			nodeColumnIdx: 2,
			checkboxColumnIdx: 0
		},
		gridnav: {
			autofocusInput: false,
			handleCursorKeys: true
		},

		renderColumns: function(event, data) {
			var node = data.node,
				$select = $("<select class='grptypesel' />"),
				$tdList = $(node.tr).find(">td");

			// (Index #0 is rendered by fancytree by adding the checkbox)
			// $tdList.eq(1).text(node.getIndexHier()).addClass("alignRight");
			// Index #2 is rendered by fancytree, but we make the title cell
			// span the remaining columns if it is a folder:
			if( node.isTopLevel() ) {
				/*
				$tdList.eq(4)
				.prop("colspan", 3)
				.nextAll().remove();
				*/
				if (node.data.loaded) {
					$tdList.eq(3).text(node.data.type);
					// $select.prop('disabled', true);
					// $(data.node.tr).find("select").prop('disabled', true);
				} else {
					var isSAN = (node.data.type == 'SANPORT');
					$("<option />", {text: "VOLUME", value: "VOLUME", selected: !isSAN}).appendTo($select);
					$("<option />", {text: "SAN port", value: "SANPORT", selected: isSAN}).appendTo($select);
					$tdList.eq(3).html($select);
				}
				var collValue = "";
				if (node.data.collection) {
					collValue = node.data.collection;
				}
				$tdList.eq(4).html("<input type='text' placeholder='Set of goups' class='collname' value='" + collValue + "'>");
			}
			if( node.getLevel() == 3 ) {
				var isPool = (node.parent.parent.data.type == 'VOLUME');
				// if (isPool && node.title == "all_pools") {
				//	node.setTitle("CPU pool");
				//}
				// $tdList.eq(4).html("<input type='checkbox' value='" + "" + "'>");
				// $tdList.eq(5).html("<input type='input' size='5' value='" + "" + "'>");
			}
			$tdList.eq(5).html("<button class='grptestbtn'>S</button>");
		},
		activate: function(event, data) {
			var node = data.node;
			// var tree = $(this).fancytree("getTree");
			$(node.tr).find("button").click();
		}
	}).on("nodeCommand", function(event, data){
		// Custom event handler that is triggered by keydown-handler and
		// context menu:
		var refNode, moveMode,
		tree = $(this).fancytree("getTree"),
		node = tree.getActiveNode();

		switch( data.cmd ) {
		case "rename":
		node.editStart();
		break;
		case "remove":
		refNode = node.getNextSibling() || node.getPrevSibling() || node.getParent();
		node.remove();
		if( refNode ) {
			refNode.setActive();
		}
		break;
		case "addGroup":
		node.editCreateNode("after", "");
		break;
		case "addServer":
		var child = {"expanded": true,"folder": true,"title":".*","children": [{"title":".*"}]};
		if (node.isTopLevel()) {
			node.editCreateNode("child", child);
		} else {
			node.editCreateNode("after", child);
		}
		break;
		case "addRule":
		if (node.getLevel() == 2) {
			node.editCreateNode("child", "");
		} else {
			node.editCreateNode("after", "");
		}
		break;
		case "addSibling":
		node.editCreateNode("after", "");
		break;
		default:
		alert("Unhandled command: " + data.cmd);
		return;
		}

	// }).on("click dblclick", function(e){
	//   console.log( e, $.ui.fancytree.eventToString(e) );

	}).on("keydown", function(e){
		var cmd = null;

		// console.log(e.type, $.ui.fancytree.eventToString(e));
		switch( $.ui.fancytree.eventToString(e) ) {
		case "del":
		case "meta+backspace": // mac
		cmd = "remove";
		break;
		// case "f2":  // already triggered by ext-edit pluging
		//   cmd = "rename";
		//   break;
		}
		if( cmd ){
		$(this).trigger("nodeCommand", {cmd: cmd});
		// e.preventDefault();
		// e.stopPropagation();
		return false;
		}
	});

		/*
	* Context menu (https://github.com/mar10/jquery-ui-contextmenu)
	*/
	$("#cgtree").contextmenu({
		delegate: "span.fancytree-node",
		menu: [
		{title: "Edit <kbd>[F2]</kbd>", cmd: "rename"},
		{title: "Delete <kbd>[Del]</kbd>", cmd: "remove"},
		{title: "----"},
		/* {title: "New Group <kbd>[Ctrl+G]</kbd>", cmd: "addGroup", disabled: true}, */
		{title: "New Storage", cmd: "addServer", disabled: true},
		{title: "New Volume", cmd: "addRule", disabled: true}
		],
		beforeOpen: function(event, ui) {
			var node = $.ui.fancytree.getNode(ui.target);
			// $("#cgtree").contextmenu("enableEntry", "addGroup", node.isTopLevel());
			$("#cgtree").contextmenu("enableEntry", "addServer", node.getLevel() == 1);
			if (node.getParentList(false,true)[0].data.type  == "VOLUME") {
				$("#cgtree").contextmenu("setEntry", "addServer", {title: "New Storage"});
				$("#cgtree").contextmenu("setEntry", "addRule", {title: "New Volume"});
			} else {
				$("#cgtree").contextmenu("setEntry", "addServer", {title: "New SAN switch"});
				$("#cgtree").contextmenu("setEntry", "addRule", {title: "New Port"});
			}
			$("#cgtree").contextmenu("enableEntry", "addRule", node.getLevel() != 1);
			node.setActive();
		},
		select: function(event, ui) {
			var that = this;
			// delay the event, so the menu can close and the click event does
			// not interfere with the edit control
			setTimeout(function(){
				$(that).trigger("nodeCommand", {cmd: ui.cmd});
			}, 100);
		}
	});

	$( "#cgtree" ).on('dblclick', "button.grptestbtn", function(event, data) {
		event.stopPropagation();
	});
	$( "#cgtree" ).on('click', "button.grptestbtn", function(event, data) {
		event.stopPropagation();
		var cgnode = $("#cgtree").fancytree("getActiveNode");
		var match = [];
		var gmatch = {};
		var vals = {};
		var count = 0;
		if( cgnode.getLevel() == 3 ) { // lowest level
			vals.lpar = cgnode.title;
			vals.srv = cgnode.parent.title;
			vals.type = cgnode.parent.parent.data.type;
			//if (vals.type == "POOL" && vals.lpar == "all_pools") {
			//	vals.lpar = "CPU pool";
			//}
			jQuery.each(fleet, function(i, val) {
				var re = new RegExp("^" + vals.srv + "$", "");
				if (re.test(i) || vals.srv == i) {
					if (fleet[i][vals.type]) {
						var grepped = jQuery.grep(fleet[i][vals.type], function( a ) {
							var regex = new RegExp("^" + vals.lpar + "$", "");
							return (regex.test(a) || vals.lpar == a);
						});
						if (grepped.length) {
							var newHTML = [];
							$.each(grepped, function(index, value) {
								newHTML.push('<span class="cgel">' + value + '</span>');
								count += 1;
							});
							if (!gmatch[i]) {
								gmatch[i] = [];
							}
							gmatch[i].push(newHTML.join(" "));
						}
					}
				}
			});
			$("#cgtest").html("<b>" + vals.type + " level rule live preview:</b> <span class='cgel'>" + cgnode.parent.parent.title + "</span><span class='rarrow'>&nbsp;&rArr;&nbsp;</span><span class='cgel'>" + cgnode.parent.title + "</span><span class='rarrow'>&nbsp;&rArr;&nbsp;</span><span class='cgel'>" + cgnode.title + "</span><hr><table>");
			if (count > 0) {
				$("#cgtest").append("<tr><th> Storage</th><th></th><th>" + vals.type + "</th></tr>");
				jQuery.each(gmatch, function(i,val) {
					$("#cgtest").append("<tr><td><span class='cgel'>" + i + "</span></td><td class='rarrow'>&nbsp;&rArr;&nbsp;</td><td>" + val.join(" ") + "</td></tr>");
				});
			} else {
				$("#cgtest").append("<tr><td>-- empty list --</td></tr>");
			}
			$("#cgtest").append("</table>").show();

		} else if( cgnode.isTopLevel() ) { // Top level
			vals.type = cgnode.data.type;
			cgnode.visit(function(tnode) {
				if( tnode.getLevel() == 3 ) { // lowest level
					vals.lpar = tnode.title;
					vals.srv = tnode.parent.title;
					if (vals.type == "POOL" && vals.lpar == "all_pools") {
						vals.lpar = "CPU pool";
					}
					jQuery.each(fleet, function(i, val) {
						var re = new RegExp("^" + vals.srv + "$", "");
						if (re.test(i) || vals.srv == i) {
							if (fleet[i][vals.type]) {
								var grepped = jQuery.grep(fleet[i][vals.type], function( a ) {
									var regex = new RegExp("^" + vals.lpar + "$", "");
									return (regex.test(a) || vals.lpar == a);
								});
								if (grepped.length) {
									var newHTML = [];
									$.each(grepped, function(index, value) {
										newHTML.push('<span class="cgel">' + value + '</span>');
										count += 1;
										if (!gmatch[i]) {
											gmatch[i] = {};
										}
										if (gmatch[i][value]) {
										gmatch[i][value] += 1;
										} else {
											gmatch[i][value] = 1;
										}
									});
								}
							}
						}
					});
				}
			});
			$("#cgtest").html("<b>" + vals.type + " group live preview:</b> <span class='cgel'>" + cgnode.title + "</span>&nbsp;&nbsp;<span style='display: none' class='cgel dupe' id='dupsfound'></span><hr><table>");
			if (count > 0) {
				$("#cgtest").append("<tr><th>Storage </th><th></th><th>" + vals.type + "</th></tr>");
				var dupsFound = 0;
				jQuery.each(gmatch, function(i,val) {
					var items = [];
					jQuery.each(val, function(ii,ival) {
						if (ival == 1) {
							items.push('<span class="cgel">' + ii + '</span>');
						} else {
							items.push('<span class="cgel dupe" title="occurrences found: ' + ival +'">' + ii + '</span>');
							dupsFound += 1;
						}
					});
					$("#cgtest").append("<tr><td><span class='cgel'>" + i + "</span></td><td class='rarrow'>&nbsp;&rArr;&nbsp;</td><td>" + items.join(" ") + "</td></tr>");
				});
			} else {
				$("#cgtest").append("<tr><td>-- empty list --</td></tr>");
			}
			$("#cgtest").append("</table>").show();
			if (dupsFound) {
				$("#dupsfound").text("some duplicates found").show();
			}
			if (sysInfo.free == 1 && count > 4) {
				$("#cgtest").append( "<hr>Due to the limitation of free LPAR2RRD distribution only the first 4 lpars/pools per group will be graphed. Unlimited number of lpars/pools in one custom group is one of the benefits of full version which comes with support subscription. <a href='http://www.lpar2rrd.com/support.htm#benefits'>More info...</a>");
			}

		} else {  // server level
			vals.type = cgnode.parent.data.type;
			cgnode.visit(function(tnode) {
				if( tnode.getLevel() == 3 ) {
					vals.lpar = tnode.title;
					vals.srv = tnode.parent.title;
					jQuery.each(fleet, function(i, val) {
						var re = new RegExp("^" + vals.srv + "$", "");
						if (re.test(i) || vals.srv == i) {
							if (fleet[i][vals.type]) {
								var grepped = jQuery.grep(fleet[i][vals.type], function( a ) {
									var regex = new RegExp("^" + vals.lpar + "$", "");
									return (regex.test(a) || vals.lpar == a);
								});
								if (grepped.length) {
									var newHTML = [];
									$.each(grepped, function(index, value) {
										newHTML.push('<span class="cgel">' + value + '</span>');
										count += 1;
										if (!gmatch[i]) {
											gmatch[i] = {};
										}
										if (gmatch[i][value]) {
										gmatch[i][value] += 1;
										} else {
											gmatch[i][value] = 1;
										}
									});
								}
							}
						}
					});
				}
			});
			$("#cgtest").html("<b>Storage level rule live preview:</b> <span class='cgel'>" + cgnode.parent.title + "</span><span class='rarrow'>&nbsp;&rArr;&nbsp;</span><span class='cgel'>" + cgnode.title + "</span> <span style='display: none' class='cgel dupe' id='dupsfound'></span><hr><table>");
			if (count > 0) {
				$("#cgtest").append("<tr><th>Storage </th><th></th><th>" + vals.type + "</th></tr>");
				var dupsFound = 0;
				jQuery.each(gmatch, function(i,val) {
					var items = [];
					jQuery.each(val, function(ii,ival) {
						if (ival == 1) {
							items.push('<span class="cgel">' + ii + '</span>');
						} else {
							items.push('<span class="cgel dupe" title="occurrences found: ' + ival +'">' + ii + '</span>');
							dupsFound += 1;
						}
					});
					$("#cgtest").append("<tr><td><span class='cgel'>" + i + "</span></td><td class='rarrow'>&nbsp;&rArr;&nbsp;</td><td>" + items.join(" ") + "</td></tr>");
				});
			} else {
				$("#cgtest").append("<tr><td>-- empty list --</td></tr>");
			}
			$("#cgtest").append("</table>").show();
			if (dupsFound) {
				$("#dupsfound").text("some duplicates found").show();
			}
		}
	});

	// Set FT data to currently selected option
	$( "#cgtree" ).on('change', "select.grptypesel", function(event, data) {
		$.ui.fancytree.getNode(event.target).data.type = event.target.value;
		$( $.ui.fancytree.getNode(event.target).tr ).find("button").click();
	});
	$( "#cgtree" ).on('click', "select.grptypesel", function(event, data) {
		event.stopPropagation();
	});
	$( "#cgtree" ).on('change', "input.collname", function(event, data) {
		$.ui.fancytree.getNode(event.target).data.collection = event.target.value;
	});
	$( "#cgtree" ).on('click', "input.collname", function(event, data) {
		var acData = $('#cgtree td:nth-child(5) input').map(function(){
				return $(this).val();
			}).get();
		acData = unique(acData);
		var field = $(event.target);
		field.autocomplete({
			autoFocus: false,
			source: acData,
			select: function( event, ui ) {
				// data.input.value =
				console.log(ui);
			},
			focus: function( event, ui ) {
				field.val( ui.item.value );
				$.ui.fancytree.getNode(event.target).data.collection = ui.item.value;
			}
		});
	});

	$("#savegrp").click(function(event) {
		event.preventDefault();
		$("#aclfile").text("");
		var delimiter = "\\:";
		var acltxt = "";
		var atxt = [];
		$("#cgtree").fancytree("getTree").visit(function(node) {
			if (node.getLevel() == 2) {
				var type = node.parent.data.type;
				var grp = node.parent.title.replace(/\:/g, delimiter);
				var col = node.parent.data.collection;
				var match = [];
				var gmatch = {};
				var vals = {};
				node.visit(function(tnode) {
					if( tnode.getLevel() == 3 ) {
						var lpar = tnode.title;
						var srv = tnode.parent.title;
						jQuery.each(fleet, function(i, val) {
							var re = new RegExp("^" + srv + "$", "");
							if (re.test(i) || srv == i) {
								if (fleet[i][type]) {
									var srvd = i.replace(/\:/g, delimiter);
									var grepped = jQuery.grep(fleet[i][type], function( a ) {
										try {
											var regex = new RegExp("^" + lpar + "$", "");
											return (regex.test(a) || lpar == a);
										}
										catch(e) {
											return (lpar == a);
										}
									});
									if (grepped.length) {
										$.each(grepped, function(index, value) {
											var line = [];
											var lpard = value.replace(/\:/g, delimiter);
											//if (type == "POOL" && rule == "CPU pool") {
											//	rule = "all_pools";
											//}
											line.push(type, srvd, lpard, grp);
											if (col) {
												line.push(col.replace(/\:/g, delimiter));
											}

											atxt.push(line.join(":"));
											acltxt += line.join(":") + "\n";
										});
									}
								}
							}
						});
					}
				});
			}
		});

		var postdata = {'acl': acltxt};

		$.post( "/stor2rrd-cgi/cgrps-save-cgi.sh", postdata, function( data ) {
			var returned = JSON.parse(data);
			if ( returned.status == "success" ) {
				$("#aclfile").text(returned.cfg).show();
			}
			$(returned.msg).dialog({
				dialogClass: "info",
				title: "Custom group configuration save - " + returned.status,
				minWidth: 600,
				modal: true,
				show: {
					effect: "fadeIn",
					duration: 500
				},
				hide: {
					effect: "fadeOut",
					duration: 200
				},
				buttons: {
					OK: function() {
						$(this).dialog("close");
					}
				}
			});
		});
	});

	$("#savedash").click(function(event) {
		event.preventDefault();
		var ttmp = '<div id="dialog-form">' +
					'<p class="validateTips">File name is required.</p>' +
					'<form>' +
						'<div id="existing" style="display: none"><select name="name" id="dbfilecombo" class="text ui-widget-content ui-corner-all"></select><br></div>' +
						'<!--label for="name">File name</label>&nbsp;&nbsp;-->' +
						'<input type="text" name="name" id="dbfilename" placeholder="Type filename..." class="text ui-widget-content ui-corner-all">' +
						'<!-- Allow form submission with keyboard without duplicating the dialog button -->' +
						'<input type="submit" tabindex="-1" style="position:absolute; top:-1000px">' +
					'</form>' +
					'</div>';
		$.getJSON("/stor2rrd-cgi/dashboard.sh?list", function(jsonData){
			cb = '';
			$.each(jsonData.sort(), function(i,data){
				var woprefix = data.substring(3);
				cb += '<option value="' + woprefix + '">' + woprefix +'</option>';
			});
			$("#dbfilecombo").html('');
			$("#dbfilecombo").append(cb).show();
			if (jsonData.length) {
				$("#existing").show();
				$("#existing").click(function(e) {
					$("#dbfilename").val(e.target.value);
				});
			}
		});
		$( ttmp ).dialog({
			dialogClass: "info",
			title: "Save DashBoard status",
			minWidth: 600,
			modal: true,
			show: {
				effect: "fadeIn",
				duration: 500
			},
			hide: {
				effect: "fadeOut",
				duration: 200
			},
			create: function( e, ui ) {
				$( this ).find( "form" ).on( "submit", function( event ) {
					event.preventDefault();
					saveDbState();
				});
			},
			buttons: {
				Save: saveDbState,
				Cancel: function() {
					$( this ).dialog( "destroy" );
					return;
				}
			}
		});
	});
	$("#loaddash").click(function(event) {
		event.preventDefault();
		var ttmp = '<div id="dialog-form">' +
					'<p class="validateTips">Your current DashBoard items will be lost!</p>' +
					'<form>' +
						'<label for="name">Select saved state name</label>&nbsp;&nbsp;' +
						'<select name="name" id="dbfilename" class="text ui-widget-content ui-corner-all"></select>' +
						'<!-- Allow form submission with keyboard without duplicating the dialog button -->' +
						'<input type="submit" tabindex="-1" style="position:absolute; top:-1000px">' +
					'</form>' +
					'</div>';
		$.getJSON("/stor2rrd-cgi/dashboard.sh?list", function(jsonData){
			cb = '';
			$.each(jsonData.sort(), function(i,data){
				var woprefix = data.substring(3);
				cb += '<option value="' + woprefix + '">' + woprefix +'</option>';
			});
			$("#dbfilename").html('');
			$("#dbfilename").append(cb);
		});
		$( ttmp ).dialog({
			dialogClass: "info",
			title: "Restore DashBoard status",
			minWidth: 600,
			modal: true,
			show: {
				effect: "fadeIn",
				duration: 500
			},
			hide: {
				effect: "fadeOut",
				duration: 200
			},
			create: function( e, ui ) {
				$( this ).find( "form" ).on( "submit", function( event ) {
					event.preventDefault();
					restorDbState();
				});
			},
			buttons: {
				Restore: restoreDbState,
				Cancel: function() {
					$( this ).dialog( "destroy" );
					return;
				}
			}
		});
	});

	$(".savealrtcfg").button().prop( "disabled", true ).click(function(event) {
		event.preventDefault();
		if ($( "input.alrtcol.ui-state-error" ).length) {
			$.alert("Please correct all marked fields before saving!", "Configuration check result", false);
			return;
		}
		$("#aclfile").text("");
		var delimiter = "\\:";
		var alertext = "";
		var alrtxt = [];
		var line = [];

		$.each($('#optform').serializeArray(), function(i, field) {
			line = [field.name, field.value].join("=");
			alrtxt.push(line);
		});
		alrtxt.push("");
		$("#alrtgrptree").fancytree("getTree").visit(function(node) {
			if (node.getLevel() == 1) {
				var grp = node.title.replace(/\:/g, delimiter),
				emails = [];
				node.visit(function(tnode) {
					emails.push(tnode.title);
				});
				alrtxt.push( ['EMAIL', grp, emails.join(",")].join(":") );
			}
		});
		alrtxt.push("");
		$("#alrttree").fancytree("getTree").visit(function(node) {
			if (node.getLevel() == 2) {
				var subsys = "VOLUME",    // shoud be node.parent.data.type later;
				storage = node.parent.title.replace(/\:/g, delimiter),
				match = [],
				gmatch = {},
				vals = {};
				node.visit(function(tnode) {
					line = [subsys, storage, tnode.parent.title, tnode.data.metric, tnode.data.limit, tnode.data.peak, tnode.data.repeat, tnode.data.exclude, tnode.data.mailgrp].join(":");
					alrtxt.push(line);
				});
			}
		});
		alertext = alrtxt.join("\n");
		var postdata = {'acl': alertext};

		$.post( "/stor2rrd-cgi/alert-save-cgi.sh", postdata, function( data ) {
			var returned = JSON.parse(data);
			if ( returned.status == "success" ) {
				$("#aclfile").text(returned.cfg).show();
				$("#alrttree").fancytree("getTree").reload();
			}
			$(returned.msg).dialog({
				dialogClass: "info",
				title: "Alerting configuration save - " + returned.status,
				minWidth: 600,
				modal: true,
				show: {
					effect: "fadeIn",
					duration: 500
				},
				hide: {
					effect: "fadeOut",
					duration: 200
				},
				buttons: {
					OK: function() {
						$(this).dialog("close");
					}
				}
			});
		});
		//if (! $("#aclfile").length ) {
		////	$(this).after("<br><pre><div id='aclfile' style='text-align: left; margin: auto; background: #fcfcfc; border: 1px solid #c0ccdf; border-radius: 10px; padding: 15px; display: none; overflow: auto'></div></pre>");
		////}
		////$("#aclfile").html(alertext).show();
	});

	function saveDbState() {
		var valid = true;
		dbfilename = $("#dbfilename");
		dbfilename.removeClass( "ui-state-error" );

		valid = valid && checkLength( dbfilename, "filename", 1, 160 )
		valid = valid && checkRegexp( dbfilename, /^([0-9a-zA-Z_\s])+$/i, "File name may consist of A-Z, a-z, 0-9, underscores and spaces." );
		if ( $('#dbfilecombo option[value="' + dbfilename.val() + '"]').length ) {
			valid = valid && confirm ("File '" + dbfilename.val() + "' already exists, do you want to overwrite");
		}

		if ( valid ) {
		// var postdata = { "save": "db_websave", "cookie" : $.cookie('dbHashes')};
		var postdata = "save=db_" + dbfilename.val() + "&cookie=" + $.cookie('dbHashes');

		$.ajax( { method: "GET" , url: "/stor2rrd-cgi/dashboard.sh", data: postdata} ).done( function( data ) {
			$(data.msg).dialog({
				dialogClass: "info",
				title: "DashBoard save - " + data.status,
				minWidth: 600,
				modal: true,
				show: {
					effect: "fadeIn",
					duration: 500
				},
				hide: {
					effect: "fadeOut",
					duration: 200
				},
				buttons: {
					OK: function() {
						$(this).dialog("destroy");
					}
				}
			});
		});
		$("#dialog-form").dialog("destroy")
		}
		return valid;
	}

	function restoreDbState() {
		dbfilename = $("#dbfilename");
		dbfilename.removeClass( "ui-state-error" );

		// var postdata = { "save": "db_websave", "cookie" : $.cookie('dbHashes')};
		var postdata = "load=db_" + dbfilename.val();

		$.get( "/stor2rrd-cgi/dashboard.sh?" + postdata, function( data ) {
			if ( data.status == "success" && data.cookie) {
				$.cookie('dbHashes', data.cookie, {
					expires: 60
				});
				$("#side-menu").fancytree("getTree").reactivate();
				$("<p>DashBoard has been succesfuly restored from " + data.filename + "</p>").dialog({
					dialogClass: "info",
					title: "DashBoard restore - " + data.status,
					minWidth: 600,
					modal: true,
					show: {
						effect: "fadeIn",
						duration: 500
					},
					hide: {
						effect: "fadeOut",
						duration: 200
					},
					buttons: {
						OK: function() {
							$(this).dialog("destroy");
						}
					}
				});
			}
		});
		$("#dialog-form").dialog("destroy");
//		genDashboard;
		return true;
	}
	var tooltips = $( "#optform [title]" ).tooltip ({
		position: {
			my: "left top",
			at: "right+5 top-5"
		},
		open: function(event, ui) {
			if (typeof(event.originalEvent) === 'undefined') {
				return false;
			}
			var $id = $(ui.tooltip).attr('id');
			// close any lingering tooltips
			$('div.ui-tooltip').not('#' + $id).remove();
			// ajax function to pull in data and add it to the tooltip goes here
		},
		close: function(event, ui) {
			ui.tooltip.hover(function() {
				$(this).stop(true).fadeTo(400, 1);
			},
			function() {
				$(this).fadeOut('400', function() {
					$(this).remove();
				});
			});
		},
		content: function () {
			return $(this).prop('title');
		}
	});

	var bar = $('.bar');
	var percent = $('.percent');
	var status = $('#status');
	$(status).hide();

	$( '#upgrade-form' ).ajaxForm({
		beforeSend: function() {
			status.empty();
			var percentVal = '0%';
			bar.width(percentVal);
			percent.html(percentVal);
			document.body.style.cursor = 'wait';
		},
		uploadProgress: function(event, position, total, percentComplete) {
			var percentVal = percentComplete + '%';
			bar.width(percentVal);
			percent.html(percentVal);
		},
		success: function(data, textStatus, jqXHR) {
			var percentVal = '100%';
			bar.width(percentVal);
			percent.html(percentVal);
			status.html("<b>Please wait, your file is being processed...</b>");
			$(status).show(200);
		},
		complete: function(xhr) {
			document.body.style.cursor = 'auto';
			status.html(xhr.responseJSON.log);
			$.alert(xhr.responseJSON.message, "Upgrade install result", xhr.responseJSON.success);
			$( "#run-data-load" ).button().on( "click", function() {
				params = { cmd: "load" };
				$.post("/stor2rrd-cgi/upgrade.sh", params, function(jsonData) {
					$.alert(jsonData.message, "Data load launched", jsonData.success);
				}, 'json');
			});
			if (xhr.responseJSON.success) {
				$("#side-menu").fancytree("getTree").reload();
				$("#side-menu").fancytree("getTree").reactivate();
			}
		}
	});

	$( "#collect-logs" ).button().on( "click", function(e) {
		e.preventDefault();  //stop the browser from following
		window.location.href = "/stor2rrd-cgi/collect_logs.sh?cmd=logs";
	});

/*
 *    $( "<button>" )
 *      .text( "Show help" )
 *      .button()
 *      .click(function() {
 *        tooltips.tooltip( "open" );
 *      })
 *      .insertAfter( "#savealcfg" );
 *
 */
}

function itemDetails(pURL, decode) {
	var host = getUrlParameters("host", pURL, decode);
	var type = getUrlParameters("type", pURL, decode);
	var vname = getUrlParameters("name", pURL, decode);
	var item = getUrlParameters("item", pURL, false);
	var time = getUrlParameters("time", pURL, false);
	if (item == 'sum') {
		item = vname;
		vname = 'sum';
	}
	// var itemcode = String.fromCharCode(97 + $.inArray(item, urlItems));
	var itemcode = "";
	try {
		itemcode = urlItems[item][1];
	} catch (exception) {
		console.log("Unknown URL item type: " + item);
	}
	var menutext = tabHead[item];
	return {
		"host": host,
		"type": type,
		"name": vname,
		"item": item,
		"time": time,
		"itemcode": itemcode,
		'menutext': menutext
	};
}

function hashRestore(hash) {
	var params = {};
	var i = hashTable[hash.substring(0, 7)];
	if (i) {
		var indexChars = hash.substring(7, 9);
		var itemIndex = jQuery.map(urlItems, function (item, index) {
			return item[1] == indexChars ? index : null;
		});
		// var itemIndex = hash.substring(7, 8).charCodeAt(0) - 97;
		var item = itemIndex[0];
		if ((i.hmc + i.srv) == "nana") {
			i.hmc = "custom-group";
			i.srv = i.type;
		}
		var time = hash.substring(9, 10);
		var lpar = i.lpar;
		params = {
			"host": i.hmc,
			"server": i.srv,
			"lpar": lpar,
			"item": item,
			"time": time,
			longname: i.longname
		};
	}
	return params;
}

function urlQstring(p, det, tot) {
	var qstring = [];
	qstring.push({
		name: "host",
		value: p.host
	});
	qstring.push({
		name: "type",
		value: p.server
	});
	qstring.push({
		name: "name",
		value: p.lpar
	});
	qstring.push({
		name: "item",
		value: p.item
	});
	qstring.push({
		name: "time",
		value: p.time
	});
	qstring.push({
		name: "detail",
		value: det
	});

	return "/stor2rrd-cgi/detail-graph.sh?" + $.param(qstring);
}


function loadImages(selector) {
	$(selector).lazy({
		bind: 'event',
		/*        delay: 0, */
		effect: 'fadeIn',
		effectTime: 400,
		threshold: 100,
		appendScroll: $("div#econtent"),
		beforeLoad: function(element) {
			element.parents("td").css("vertical-align", "middle");
		},
		onLoad: function(element) {
			if ( $(element).hasClass("nolegend") ) {
				$.getJSON(element.attr("data-src"), function(data, textStatus, jqXHR) {
					var header = jqXHR.getResponseHeader('X-RRDGraph-Properties');
					if (header) {
						if (sysInfo.guidebug == 1) {
							$(element).parent().attr("title", header);
						}
						var h = header.split(":");
						var frame = $(element).siblings("div.zoom");
						$(frame).imgAreaSelect({
							remove: true
						});
						$(frame).data("graph_start", h[4]);
						$(frame).data("graph_end", h[5]);
						$(frame).css("left", h[0] + "px");
						$(frame).css("top", h[1] + "px");
						$(frame).css("width", h[2] + "px");
						$(frame).css("height", h[3] + "px");
						if (h[2] && h[3]) {
							zoomInit(frame.attr("id"), h[2], h[3]);
						}
						frame.show();
						// console.log(h);
					}
					element.attr("src", data.img);
					// loadImages(curImg);
					$(element).parents(".relpos").find("div.legend").html(Base64.decode(data.table));
					var $t = element.parents(".relpos").find('table.tablesorter');
					if ($t.length) {
						var updated = $t.find(".tdupdated");
						if (updated) {
							element.parents(".detail").siblings(".updated").text(updated.text());
							updated.parent().remove();
						}
						tableSorter($t);
						$t.find("a").click(function() {
							var url = $(this).attr('href');
							if ((url.substring(0, 7) != "http://") && (!/\.csv$/.test(url)) && (!/lpar-list-rep\.sh/.test(url)) && ($(this).text() != "CSV")) {
								backLink(url);
								return false;
							}
						});
						$t.find("td.legsq").each(function() {
							$(this).next().attr("title", $(this).next().text()); // set tooltip (to see very long names)
							var bgcolor = $(this).text();
							if (bgcolor) {
								var parLink = $(this).parents(".relpos").find("a.detail").attr("href");
								var parParams = getParams(parLink);
								// var trTime = trTime.match(/&time=([dwmy])/)[1];
								trItem = parParams.item;
								if (trItem == "sum") {
									trItem = parParams.name;
								}
								var trTime = parParams.time;
								var trLink = $(this).parent().find(".clickabletd a").last().attr("href");
								var trParams = getParams(trLink);
								if (trParams.item == "pool") {
									if (trParams.lpar == "pool") {
										trItem = "pool"
									} else {
										trItem = "shpool"
									}
								}
								if (trParams.square_item) {
									trItem = trParams.square_item;
								}
								trLink = "/stor2rrd-cgi/detail-graph.sh?host=" + trParams.host + "&type=" + trParams.type + "&name=" + trParams.name +
									"&item=" + trItem + "&time=" + trTime + "&detail=1&none=";
								if (trParams.name) {
									$(this).html("<a href='" + trLink + "' title='Click to get [" + decodeURIComponent(trParams.name.replace(/\+/g, " ")) + "] detail in a pop-up view' class='detail'><div class='innersq' style='background:" + bgcolor + ";'></div></a>");
									$(this).find('a.detail').fancybox({
										type: 'image',
										// transitionIn: 'none',
										// transitionOut: 'none',
										live: false,
										helpers : {
											title : null
										},
										titleShow: false,
										speedIn: 400,
										speedOut: 100,
										autoScale: false, // images won't be scaled to fit to browser's height
										maxWidth: "98%",
										overlay: {
											showEarly: false,
											css: {
												'background': 'rgba(58, 42, 45, 0.95)'
											}
										},
										hideOnContentClick: true
									});
								} else {
									$(this).html("<div class='innersq' style='background:" + bgcolor + ";'></div>");
								}
							}
						});
						if ($t.find("a.detail").length) {
							$t.find("tr").find("th").first().addClass("popup").attr("title", "Click on the color square below to get item detail in a pop-up view");
						}
						if (sysInfo.legend_height) {
								$t.parent().css("max-height", sysInfo.legend_height + "px");
						}
						$(element).parents(".relpos").find("div.legend").jScrollPane (
							{
								showArrows: false,
								horizontalGutter: 30,
								verticalGutter: 30
							}
						);
					}
					$(element).parents("td.relpos").css("vertical-align", "top");
					$(element).parents("td.relpos").css("text-align", "left");
					$(element).parents(".relpos").find("div.favs").show();
					$(element).parents(".relpos").find("div.dash").show();
					$(element).parents(".relpos").find("div.popdetail").show();
				});
			} else {
				jQuery.ajax({
					// url: $(element).attr("data-src") + "&none=" + new Date().getTime(),
					url: $(element).attr("data-src"),
					//   complete: function (jqXHR, textStatus) {
					success: function(data, textStatus, jqXHR) {
						var header = jqXHR.getResponseHeader('X-RRDGraph-Properties');
						if (header) {
							if (sysInfo.guidebug == 1) {
								$(element).parent().attr("title", header);
							}
							var h = header.split(":");
							var frame = $(element).siblings("div.zoom");
							$(frame).imgAreaSelect({
								remove: true
							});
							$(frame).data("graph_start", h[4]);
							$(frame).data("graph_end", h[5]);
							$(frame).css("left", h[0] + "px");
							$(frame).css("top", h[1] + "px");
							$(frame).css("width", h[2] + "px");
							$(frame).css("height", h[3] + "px");
							if (h[2] && h[3]) {
								zoomInit(frame.attr("id"), h[2], h[3]);
							}
							frame.show();
							// console.log(h);
						}
					}
				});
			}
		},
		afterLoad: function(element) {
			$(element).removeClass('load');
			$(element).parents("td.relpos").css("vertical-align", "top");
			$(element).parents("td.relpos").css("text-align", "left");
			$(element).parents("td.relpos").find("div.favs").show();
			$(element).parents("td.relpos").find("div.dash").show();
			$(element).parents("td.relpos").find("div.popdetail").show();
		}
	});
}

function setTitle(menuitem) {
	var item = '';
	var path = '';
	var parents = menuitem.getParentList(false, true);
	var delimiter = '<span class="delimiter">&nbsp;&nbsp;|&nbsp;&nbsp;</span>';

	$.each(parents, function(key, part) {
		item = part.title;
		if (item.indexOf(prodName + " <span") >= 0) {
			item = prodName;
		}
		if (item != 'Items' && item != 'Totals' && item != "STORAGE") {
			if (path === '') {
				path = item;
			} else {
				path += delimiter + item;
			}
		}
	});

	if ((curNode.key != "_1") && (curNode.title != "Historical reports") && ($('#tabs').length)) {
		var tabText = $('#tabs li.ui-tabs-active').text();
		if ( tabHead.tabText ) {
			path += delimiter + tabHead.tabText;
		} else {
			path += delimiter + tabText;
		}
	}


	$('#title').html(path);
	$('#title').show();
}

function hrefHandler() {
	$('#content a:not(.ui-tabs-anchor, .detail)').click(function() {
		var url = $(this).attr('href');
		if ((url.substring(0, 7) != "http://") && (!/\.csv$/.test(url)) && (!/lpar-list-rep\.sh/.test(url)) && ($(this).text() != "CSV")) {
			backLink(url);
			return false;
		}
	});
}

function backLink(pURL) {
	if (pURL == "#") {
		return false;
	}
	if (pURL.indexOf("?") >= 0) {
		var itemType = getUrlParameters("type", pURL, true);
		if (itemType == "POOL" || itemType == "RANK" || itemType == "PORT" || itemType == "DRIVE" || itemType == "VOLUME" || itemType == "HOST") {
			host = getUrlParameters("host", pURL, true);
			lpar = getUrlParameters("name", pURL, true);
			$tree = $("#side-menu").fancytree("getTree");
			$tree.visit(function(node) {
				if (node.data.altname == lpar || node.title == lpar) {
					var par1 = node.getParent(); // skip Items level
					if (lpar != "cap" && lpar != "data" && lpar != "io" && itemType != "HOST") {
						par1 = par1.getParent();     // get class level
					}
					if (par1.title == itemType || par1.title == (itemType=="RANK" ? "Managed disk" : "")|| par1.title == (itemType=="RANK" ? "RAID GROUP" : "") ) {
						par1 = par1.getParent();
						if (par1.title == host) {
							node.setExpanded(true);
							node.setActive();
							return false;
						}
					}
				}
			});
		} else if (itemType == "Data" || itemType == "Frame") {
			host = getUrlParameters("host", pURL, true);
			$tree = $("#side-menu").fancytree("getTree");
			$tree.visit(function(node) {
				if (node.title == itemType) {
					var par1 = node.getParent(); // skip Items level
					if (par1.title == host) {
						node.setExpanded(true);
						node.setActive();
						return false;
					}
				}
			});
		} else if (itemType == "SANPORT") {
			host = getUrlParameters("host", pURL, true);
			lpar = getUrlParameters("name", pURL, true);
			$tree = $("#side-menu").fancytree("getTree");
			$tree.visit(function(node) {
				if (node.data.altname == lpar || node.title == lpar) {
					var par1 = node.getParent(); // skip Items level
					par1 = par1.getParent();     // get class level
					if (par1.title == host) {
						node.setExpanded(true);
						node.setActive();
						return false;
					}
				}
			});
		}
	} else if (pURL.indexOf("gui-cpu.html") >= 0) {
		splitted = pURL.split("/");
		server = splitted[1];
		$tree = $("#side-menu").fancytree("getTree");
		$tree.visit(function(node) {
			if (node.title == "Totally for all CPU pools" || node.title == "CPU pool") {
				var par1 = node.getParent(); // skip LPARs level
				if (par1.title == server) {
					node.setExpanded(true);
					node.setActive();
					return false;
				}
			}
		});
	} else if (pURL.indexOf("health_status.html") >= 0) {
        splitted = pURL.split("/");
        server = splitted[0];
        $tree = $("#side-menu").fancytree("getTree");
        $tree.visit(function(node) {
            if (node.title == "Health status") {
                var par1 = node.getParent(); // skip LPARs level
                if (par1.title == server) {
                    node.setExpanded(true);
                    node.setActive();
                    return false;
                }
            }
        });
	} else if (pURL.indexOf("config.html") >= 0  && curNode.title != "Configuration") {
        splitted = pURL.split("/");
        server = splitted[0];
        $tree = $("#side-menu").fancytree("getTree");
        $tree.visit(function(node) {
            if (node.title == "Configuration") {
                var par1 = node.getParent(); // skip LPARs level
                if (par1.title == server) {
                    node.setExpanded(true);
                    node.setActive();
                    return false;
                }
            }
        });
	} else {
		var splitted = pURL.split("#");
		if (splitted[1]) {
			jumpTo = splitted[1];
		} else {
			jumpTo = "";
		}

		$('#content').load(pURL, function() {
			if (jumpTo) {
				jumpTo = decodeURI(jumpTo);
				location.hash = jumpTo;
			}
			imgPaths();
			myreadyFunc();
		});
	}
}


function getUrlParameters(parameter, url, decode) {
	var parArr = url.split("?")[1].split("&"),
		returnBool = true;

	for (var i = 0; i < parArr.length; i++) {
		parr = parArr[i].split("=");
		if (parr[0] == parameter) {
			return (decode) ? decodeURIComponent(parr[1].replace(/\+/g, " ")) : parr[1];
		} else {
			returnBool = false;
		}
	}
	if (!returnBool) {
		return false;
	}
}

function areCookiesEnabled() {
	var cookieEnabled = (navigator.cookieEnabled) ? true : false;

	if (typeof navigator.cookieEnabled == "undefined" && !cookieEnabled) {
		document.cookie = "testcookie";
		cookieEnabled = (document.cookie.indexOf("testcookie") != -1) ? true : false;
	}
	return (cookieEnabled);
}

function copyToClipboard(text) {
	window.prompt("GUI DEBUG: Please copy following content to the clipboard (Ctrl+C), then paste it to the bugreport (Ctrl-V)", text);
}

/*
function download(filename, text) {
	var pom = document.createElement('a');
	pom.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
	pom.setAttribute('download', filename);
	pom.click();
}

function arrayBytes(arr) {
	var g = JSON.stringify(arr).replace(/[\[\]\,\"]/g, ''); //stringify and remove all "stringification" extra data
	return (g.length); //this will be your length.
}
*/

function dataSource() {
	$("#datasrc").removeClass();
	$("#datasrc").hide();
	if ($('li.tabfrontend, li.tabbackend').length > 0) {
		var activeTab = $('#tabs li.ui-tabs-active');
		var title = "Data source: ";
		var cls = "";
		if (activeTab.hasClass("tabfrontend")) {
			title += "Frontend data";
			cls = "agent";
		} else if (activeTab.hasClass("tabbackend")) {
			title += "Backend data";
			cls = "nmon";
		} else if ($('li.tabfrontend').length > 0) {
			title += "Frontend data";
			cls = "agent";
		} else {
			title += "Backend data";
			cls = "nmon";
		}
		$("#datasrc").attr("title", title);
		$("#datasrc").addClass(cls);
		$("#datasrc").show();
	} else {
		$("#datasrc").addClass("none");
	}
}

function showHideSwitch() {
	if (curNode.parent.title == "Items" && curNode.parent.parent.title == "VOLUME") {
		var dataSources = "";
		if ($("ul.ui-tabs-nav").has("li.tabfrontend").length) {
			dataSources = "frontend";
		}
		if ($("ul.ui-tabs-nav").has("li.tabbackend").length) {
			if (dataSources == "frontend") {
				dataSources = "all"; // both OS agent and NMON data present
			} else {
				dataSources = "backend"; // just NMON data present
			}
		}
		if (dataSources == "all") {
			var activeTab = $('#tabs li.ui-tabs-active.tabfrontend,#tabs li.ui-tabs-active.tabbackend').text();
			if (activeTab) {
				$("#nmonsw").show();
			} else {
				$("#nmonsw").hide();
			}
		} else {
			$("#nmonsw").hide();
		}
		agentNmonToggle(dataSources);
	} else {
		$("#nmonsw").hide();
	}
}

//*************** Toggle agent/nmon data

function agentNmonToggle(src) {
	if (src == 'all') {
		if (($("#nmr1").is(':checked')) || src == "agent") {
			$("ul.ui-tabs-nav li.tabbackend").css("display", "none");
			$("ul.ui-tabs-nav li.tabfrontend").css("display", "inline-block");
		}

		if (($("#nmr2").is(':checked')) || src == "nmon") {
			$("ul.ui-tabs-nav li.tabbackend").css("display", "inline-block");
			$("ul.ui-tabs-nav li.tabfrontend").css("display", "none");
		}
	}
}

function histRepQueryString(managedName) {
	// get HMC & server name from menu url
	// var serverPath = $("#side-menu").fancytree('getActiveNode').data.href.split('/');
	var storage = curNode.parent.title;
	var queryArr = [{
		name: 'jsontype',
		value: 'histrep'
	}, {
		name: 'hmc',
		value: storage
	}, {
		name: 'managedname',
		value: managedName
	}];
	return $.param(queryArr);
}

function sections() {
	// return;
	if (sysInfo.demo == "1") {
		var allSources = $("ul.ui-tabs-nav").has("li.tabbackend", "li.tabfrontend").length;
		if ($("li.tabhmc").length > 0) {
			$("#fsh").width(function() {
				var sectWidth = 0;
				$("li.tabhmc").each(function() {
					sectWidth += $(this).outerWidth() + 1;
				});
				return sectWidth - 1;
			});
			$("#fsh").show();
		} else {
			$("#fsh").hide();
		}

		if ($("li.tabfrontend").length > 0) {
			$("#fsa").width(function() {
				var sectWidth = 0;
				$("li.tabfrontend").each(function() {
					sectWidth += $(this).outerWidth() + 1;
				});
				return sectWidth - 1;
			});
			if (allSources === 0) {
				$("#fsa").show();
			} else if ($("#nmr1").is(':checked')) {
				$("#fsa").show();
			} else {
				$("#fsa").hide();
			}
		} else {
			$("#fsa").hide();
		}

		if ($("li.tabbackend").length > 0) {
			$("#fsn").width(function() {
				var sectWidth = 0;
				$("li.tabbackend").each(function() {
					sectWidth += $(this).outerWidth() + 1;
				});
				return sectWidth - 1;
			});
			if (allSources === 0) {
				$("#fsn").show();
			} else if ($("#nmr2").is(':checked')) {
				$("#fsn").show();
			} else {
				$("#fsn").hide();
			}
		} else {
			$("#fsn").hide();
		}
	} else {
		$("#subheader fieldset").hide();
	}
}

function tableSorter(tabletosort) {
	var sortList = {};
	$(tabletosort).find("th").each(function(i, header) {
		if (!$(header).hasClass('sortable')) {
			sortList[i] = {
				"sorter": false
			};
		}
	});
	sortArray = [];
	if ($(tabletosort).data().sortby) {
		sortArray = [[$(tabletosort).data().sortby - 1, 1]];
	}
	$(tabletosort).tablesorter({
		sortInitialOrder: 'desc',
		stringTo: 'bottom',
		theme: "ice",
		headers: sortList,
		widgets : [ "filter" ],
		sortList: sortArray,
		widgetOptions : {
			// filter_anyMatch options was removed in v2.15; it has been replaced by the filter_external option

			// If there are child rows in the table (rows with class name from "cssChildRow" option)
			// and this option is true and a match is found anywhere in the child row, then it will make that row
			// visible; default is false
			filter_childRows : false,

			// if true, filter child row content by column; filter_childRows must also be true
			filter_childByColumn : false,

			// if true, include matching child row siblings
			filter_childWithSibs : true,

			// if true, a filter will be added to the top of each table column;
			// disabled by using -> headers: { 1: { filter: false } } OR add class="filter-false"
			// if you set this to false, make sure you perform a search using the second method below
			filter_columnFilters : true,

			// if true, allows using "#:{query}" in AnyMatch searches (column:query; added v2.20.0)
			filter_columnAnyMatch: true,

			// extra css class name (string or array) added to the filter element (input or select)
			filter_cellFilter : '',

			// extra css class name(s) applied to the table row containing the filters & the inputs within that row
			// this option can either be a string (class applied to all filters) or an array (class applied to indexed filter)
			filter_cssFilter : '', // or []

			// add a default column filter type "~{query}" to make fuzzy searches default;
			// "{q1} AND {q2}" to make all searches use a logical AND.
			filter_defaultFilter : {},

			// filters to exclude, per column
			filter_excludeFilter : {},

			// jQuery selector (or object) pointing to an input to be used to match the contents of any column
			// please refer to the filter-any-match demo for limitations - new in v2.15
			filter_external : '',

			// class added to filtered rows (rows that are not showing); needed by pager plugin
			filter_filteredRow : 'filtered',

			// add custom filter elements to the filter row
			// see the filter formatter demos for more specifics
			filter_formatter : null,

			// add custom filter functions using this option
			// see the filter widget custom demo for more specifics on how to use this option
			filter_functions : null,

			// hide filter row when table is empty
			filter_hideEmpty : true,

			// if true, filters are collapsed initially, but can be revealed by hovering over the grey bar immediately
			// below the header row. Additionally, tabbing through the document will open the filter row when an input gets focus
			filter_hideFilters : true,

			// Set this option to false to make the searches case sensitive
			filter_ignoreCase : true,

			// if true, search column content while the user types (with a delay)
			filter_liveSearch : true,

			// a header with a select dropdown & this class name will only show available (visible) options within that drop down.
			filter_onlyAvail : 'filter-onlyAvail',

			// default placeholder text (overridden by any header "data-placeholder" setting)
			filter_placeholder : { search : '', select : '' },

			// jQuery selector string of an element used to reset the filters
			filter_reset : 'button.reset',

			// Reset filter input when the user presses escape - normalized across browsers
			filter_resetOnEsc : true,

			// Use the $.tablesorter.storage utility to save the most recent filters (default setting is false)
			filter_saveFilters : true,

			// Delay in milliseconds before the filter widget starts searching; This option prevents searching for
			// every character while typing and should make searching large tables faster.
			filter_searchDelay : 300,

			// allow searching through already filtered rows in special circumstances; will speed up searching in large tables if true
			filter_searchFiltered: true,

			// include a function to return an array of values to be added to the column filter select
			filter_selectSource  : null,

			// if true, server-side filtering should be performed because client-side filtering will be disabled, but
			// the ui and events will still be used.
			filter_serversideFiltering : false,

			// Set this option to true to use the filter to find text from the start of the column
			// So typing in "a" will find "albert" but not "frank", both have a's; default is false
			filter_startsWith : false,

			// Filter using parsed content for ALL columns
			// be careful on using this on date columns as the date is parsed and stored as time in seconds
			filter_useParsedData : false,

			// data attribute in the header cell that contains the default filter value
			filter_defaultAttrib : 'data-value',

			// filter_selectSource array text left of the separator is added to the option value, right into the option text
			filter_selectSourceSeparator : '|'
		}
	});
}

/*
function queryStringToHash(query) {
	var query_string = {},
		vars = query.split("&");

	for (var i = 0; i < vars.length; i++) {
		var pair = vars[i].split("=");
		pair[0] = decodeURIComponent(pair[0]);
		pair[1] = decodeURIComponent(pair[1]);
		// If first entry with this name
		if (typeof query_string[pair[0]] === "undefined") {
			query_string[pair[0]] = pair[1];
			// If second entry with this name
		} else if (typeof query_string[pair[0]] === "string") {
			var arr = [query_string[pair[0]], pair[1]];
			query_string[pair[0]] = arr;
			// If third or later entry with this name
		} else {
			query_string[pair[0]].push(pair[1]);
		}
	}
	return query_string;
}

/*
 * Returns a map of querystring parameters
 *
 * Keys of type <fieldName>[] will automatically be added to an array
 *
 * @param String url
 * @return Object parameters
 */
function getParams(url, decode) {
	var regex = /([^=&?]+)=([^&#]*)/g,
		params = {},
		parts, key, value;

	while ((parts = regex.exec(url)) != null) {

		key = parts[1];
		value = parts[2];
		if (decode) {
			value = decodeURIComponent(value);
		}
		var isArray = /\[\]$/.test(key);

		if (isArray) {
			params[key] = params[key] || [];
			params[key].push(value);
		} else {
			params[key] = value;
		}
	}

	return params;
}

/*
function ShowDate(ts) {
	var then = ts.getFullYear() + '-' + (ts.getMonth() + 1) + '-' + ts.getDay();
	then += ' ' + ts.getHours() + ':' + ts.getMinutes();
	return (then);
}
*/

function zoomInit(zoomID, width, height) {
	$("#" + zoomID).imgAreaSelect({
		handles: false,
		maxHeight: height,
		minHeight: height,
		maxWidth: width,
		parent: "#content",
		fadeSpeed: 500,
		autoHide: true,
		onSelectEnd: function(img, selection) {
			if (selection.width) {
				var from = new Date($(img).data().graph_start * 1000);
				var to = new Date($(img).data().graph_end * 1000);
				var timePerPixel = (to - from) / $(img).width();
				var selFrom = new Date(+from + selection.x1 * timePerPixel);
				var selTo = new Date(+selFrom + selection.width * timePerPixel);
				storedObj = $(img).parents("a.detail");
				storedUrl = $(storedObj).attr("href");
				var nonePos = storedUrl.indexOf('&none');
				zoomedUrl = storedUrl.slice(0, nonePos);
				zoomedUrl += "&sunix=" + selFrom.getTime() / 1000;
				zoomedUrl += "&eunix=" + selTo.getTime() / 1000;
				$(storedObj).attr("href", zoomedUrl);
				$(storedObj).click();
			}
		}
	});
}

/* placeholder for input fields */
function placeholder() {
	$("input[type=text]").each(function() {
		var phvalue = $(this).attr("placeholder");
		$(this).val(phvalue);
	});
}

function CheckExtension(file) {
	/*global document: false */
	var validFilesTypes = ["nmon", "csv"];
	var filePath = file.value;
	var ext = filePath.substring(filePath.lastIndexOf('.') + 1).toLowerCase();
	var isValidFile = false;

	for (var i = 0; i < validFilesTypes.length; i++) {
		if (ext == validFilesTypes[i]) {
			isValidFile = true;
			break;
		}
	}

	if (!isValidFile) {
		file.value = null;
		alert("Invalid File. Valid extensions are:\n\n" + validFilesTypes.join(", "));
	}

	return isValidFile;
}

function getUrlParameter(sParam)
{
	var sPageURL = window.location.search.substring(1);
	var sURLVariables = sPageURL.split('&');
	for (var i = 0; i < sURLVariables.length; i++)
	{
		var sParameterName = sURLVariables[i].split('=');
		if (sParameterName[0] == sParam)
		{
			return sParameterName[1];
		}
	}
}

function saveData (id) {
	if (!sessionStorage) {
		return;
	}
	var data = {
		id: id,
		scroll: $("#content").scrollTop(),
		title: $("#title").html(),
		html: $("#content").html()
	};
	sessionStorage.setItem(id,JSON.stringify(data));
}
function restoreData (id) {
    if (!sessionStorage) {
        return;
	}
    var data = sessionStorage.getItem(id);
    if (!data) {
        return null;
	}
    return JSON.parse(data);
}

function detectIE() {
    var ua = window.navigator.userAgent;
    var msie = ua.indexOf('MSIE ');
    var trident = ua.indexOf('Trident/');

    if (msie > 0) {
        // IE 10 or older => return version number
        return parseInt(ua.substring(msie + 5, ua.indexOf('.', msie)), 10);
    }

    if (trident > 0) {
        // IE 11 (or newer) => return version number
        var rv = ua.indexOf('rv:');
        return parseInt(ua.substring(rv + 3, ua.indexOf('.', rv)), 10);
    }

    // other browser
    return false;
}

// Create Base64 Object
var Base64={_keyStr:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",encode:function(e){var t="";var n,r,i,s,o,u,a;var f=0;e=Base64._utf8_encode(e);while(f<e.length){n=e.charCodeAt(f++);r=e.charCodeAt(f++);i=e.charCodeAt(f++);s=n>>2;o=(n&3)<<4|r>>4;u=(r&15)<<2|i>>6;a=i&63;if(isNaN(r)){u=a=64}else if(isNaN(i)){a=64}t=t+this._keyStr.charAt(s)+this._keyStr.charAt(o)+this._keyStr.charAt(u)+this._keyStr.charAt(a)}return t},decode:function(e){var t="";var n,r,i;var s,o,u,a;var f=0;e=e.replace(/[^A-Za-z0-9\+\/\=]/g,"");while(f<e.length){s=this._keyStr.indexOf(e.charAt(f++));o=this._keyStr.indexOf(e.charAt(f++));u=this._keyStr.indexOf(e.charAt(f++));a=this._keyStr.indexOf(e.charAt(f++));n=s<<2|o>>4;r=(o&15)<<4|u>>2;i=(u&3)<<6|a;t=t+String.fromCharCode(n);if(u!=64){t=t+String.fromCharCode(r)}if(a!=64){t=t+String.fromCharCode(i)}}t=Base64._utf8_decode(t);return t},_utf8_encode:function(e){e=e.replace(/\r\n/g,"\n");var t="";for(var n=0;n<e.length;n++){var r=e.charCodeAt(n);if(r<128){t+=String.fromCharCode(r)}else if(r>127&&r<2048){t+=String.fromCharCode(r>>6|192);t+=String.fromCharCode(r&63|128)}else{t+=String.fromCharCode(r>>12|224);t+=String.fromCharCode(r>>6&63|128);t+=String.fromCharCode(r&63|128)}}return t},_utf8_decode:function(e){var t="";var n=0;var r=c1=c2=0;while(n<e.length){r=e.charCodeAt(n);if(r<128){t+=String.fromCharCode(r);n++}else if(r>191&&r<224){c2=e.charCodeAt(n+1);t+=String.fromCharCode((r&31)<<6|c2&63);n+=2}else{c2=e.charCodeAt(n+1);c3=e.charCodeAt(n+2);t+=String.fromCharCode((r&15)<<12|(c2&63)<<6|c3&63);n+=3}}return t}}

function groupTable($rows, startIndex, total) {
	if (total === 0) {
		return;
	}
	var i , currentIndex = startIndex, count=1, lst=[];
	var tds = $rows.find('td:eq('+ currentIndex +')');
	var ctrl = $(tds[0]);
	lst.push($rows[0]);
	for (i=1;i<=tds.length;i++) {
		if (ctrl.text() ==  $(tds[i]).text()) {
			count++;
			$(tds[i]).addClass('deleted');
			lst.push($rows[i]);
		} else {
			if (count>1) {
				ctrl.attr('rowspan',count);
				groupTable($(lst),startIndex+1,total-1)
			}
			count=1;
			lst = [];
			ctrl=$(tds[i]);
			lst.push($rows[i]);
		}
	}
}

function unique(array) {
	return $.grep(array, function(el, index) {
		return index === $.inArray(el, array);
	});
}

function checkLength( o, n, min, max ) {
	if ( o.val().length > max || o.val().length < min ) {
		o.addClass( "ui-state-error" );
		updateTips( "Length of " + n + " must be between " + min + " and " + max + "." );
		return false;
	} else {
		return true;
	}
}

function checkRegexp( o, regexp, n ) {
	if ( !( regexp.test( o.val() ) ) ) {
		o.addClass( "ui-state-error" );
		updateTips( n );
		return false;
	} else {
		o.removeClass( "ui-state-error" );
		return true;
	}
}

function updateTips( t ) {
	tips = $( ".validateTips" );
	tips
	.text( t )
	.addClass( "ui-state-highlight" );
	setTimeout(function() {
		tips.removeClass( "ui-state-highlight", 1500 );
	}, 500 );
}

RegExp.escape = function(text) {
	return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
};

function checkStatus () {
	if (!sysInfo.demo) {
		$.getJSON("/stor2rrd-cgi/genjson.sh?jsontype=isok", function(data) {
			if (data.status == "NOK") {
				$tree = $("#side-menu").fancytree("getTree");
				if ($("#redpoint").length == 0) {
					var redPoint = '<img src="css/images/alert.png" id="redpoint" style="margin-left: 2px; margin-top: -1px;">';
					$($tree.rootNode.children[1].span).append(redPoint);
				}
			} else {
				if ($("#redpoint").length) {
					$("#redpoint").remove();
				}
			}
		});
	}
}

function genCapacity () {
	var content = $('#content');
	$('#title').html("Capacity").show();
	$.getJSON("/stor2rrd-cgi/genjson.sh?jsontype=caps", function(data) {
		if (data) {
			content.empty();
			var re = /\s*([\d|\.]+)/gi;
			content.append ("<center><br><table class='captab tabconfig tablesorter'><thead><tr><th class='sortable'>Storage</th><th class='sortable'>Type</th><th class='sortable'>Total</th><th class='sortable'>Free</th><th class='sortable'>Used</th><th class='sortable'>Percentage</th></tr></thead><tbody></tbody></table>");
			content.append("<div id='caps'></div>");

			var deferreds = [],
			rowclass = "",
			dataLines = [];
			$.each(data, function(key, val) {
				// val.url = "/sgui/cap2.txt";  // debug line
				deferreds.push(
					$.get(val.url, function (capdata) {
						dataLines.push(capdata);
						var clines = capdata.replace(/print\[\d+\] = /g, "");
						clines = clines.replace(/"/g, "");
						clines = clines.replace(/^\s*\n/gm, "");
						clines = clines.split("\n");
						capline = {};
						$.each(clines, function(i, txt) {
							if (txt) {
								$.trim(txt);
								// var pair = txt.split(/\s+/, 2);
								var pair = txt.split(/\s(.+)?/);
								var tier = pair[0].split(/(total|free|used|time)/g);
								if (tier[2] == "") {
									tier[2] = "Total";
								}
								if (!capline[tier[2]]) {
									capline[tier[2]] = {};
								}
								capline[tier[2]][tier[1]] = pair[1];
							}
						});
						$.each(capline, function(i, line) {
							if (i == "Total" || line.total >0) {
								var perc = round(line.used / line.total*100, 0),
								total = roundUnit(line.total, 2),
								free = roundUnit(line.free, 2),
								used = roundUnit(line.used, 2),
								scurl = "/stor2rrd-cgi/detail.sh?host=" + val.storage + "&type=" + val.subsys + "&name=cap";
								if (i != "Total") {
									i = "<span class='tier'>" + i + "</span>";
									shref = "<a class='hidden' href='" + scurl + "'>" + val.storage + "</a>";
								} else {
									shref = "<a href='" + scurl + "'>" + val.storage + "</a>";
								}
								if(key & 1) {
									rowclass = " class='even'";
								} else {
									rowclass = "";
								}
								// meter = "<meter value='" + used + "' min='0' max='" + total + "' optimum='0' low='" + total*0.8 + "' high='" + total*0.97 + "' title='" + perc + "% of storage capacity used'>" + perc + "</meter>",
								meter = "<meter value='" + perc + "' min='0' max='100' optimum='0' low='80' high='95' title='" + perc + "% of storage capacity used (" + capline.Total.time + ")'>" + perc + "</meter>",
								row = "<tr" + rowclass + "><td><b>" + shref + "</b></td><td>" + i + "</td><td class='tdr'>" + total + "</td><td class='tdr'>" + free + "</td><td class='tdr'>" + used + "</td><td>" + meter + "</td></tr>";
								content.find('tbody').append(row);
							}
						});
					})
				);
			});
			$.when.apply($, deferreds).done(function() {
				var sortArray = [[0, 0]];
				$(content.find('table')).tablesorter({
					sortInitialOrder: 'desc',
					stringTo: 'bottom',
					sortList: sortArray,
					headers: {
						2: {
							sorter: 'metric'
						},
						3: {
							sorter: 'metric'
						},
						4: {
							sorter: 'metric'
						},
					}
				});
				hrefHandler();
				$('meter').html5jpMeterPolyfill();
			});

		}
	});
}

function round(value, decimals) {
	return Number(Math.round(value+'e'+decimals)+'e-'+decimals);
}

function roundUnit(value, decimals) {
	var unit = " TB";
	if (value > 1000000) {
		value /= 1000000;
		unit = " EB";
	} else if (value > 1000) {
		value /= 1000;
		unit = " PB";
	} else if (value < 1) {
		value *= 1000;
		unit = " GB";
	}
	return Number(Math.round(value+'e'+decimals)+'e-'+decimals) + unit;
}

// add parser through the tablesorter addParser method
$.tablesorter.addParser({
	// set a unique id
	id: 'metric',
	is: function(s) {
		// return false so this parser is not auto detected
		return false;
	},
	format: function(s) {
		var prefixes = {
			E: Math.pow(1024, 6), // 1024^6
			P: Math.pow(1024, 5), // 1024^5
			T: Math.pow(1024, 4), // 1024^4
			G: Math.pow(1024, 3), // 1024^3
			M: Math.pow(1024, 2), // 1024^2
		}
		regAbbr = /([\d\.]+)(\s+)?(E|P|T|G|M)/i;
		re = s.match(regAbbr);
		val = re[1];
		unit = re[3];
		// format your data for normalization
		return val * prefixes[unit];
	},
	// set type, either numeric or text
	type: 'numeric'
});

var addNewAlertDiv = '<div id="alert-dialog-form"> \
  <p class="validateTips">All form fields are required.</p> \
  <form autocomplete="off"> \
    <fieldset> \
      <label for="storagesel">Storage</label> \
      <select class="alrtcol" name="storage" id="storagesel" /></br> \
      <label for="volumesel" style="margin-top: 4px">Volume</label> \
      <select class="alrtcol" style="margin-top: 4px" name="volume" id="volumesel" /> \
      <!-- Allow form submission with keyboard without duplicating the dialog button --> \
      <input type="submit" tabindex="-1" style="position:absolute; top:-1000px"> \
    </fieldset> \
  </form> \
</div>';

function addNewAlrtForm (title, oParams) {
	$( addNewAlertDiv ).dialog({
		height: 250,
		width: 450,
		modal: true,
		title: title,
		buttons: {
			"Add new alerting rule": addNewAlert,
			Cancel: function() {
				$(this).dialog("close");
			}
		},
		create: function() {
			alertForm = $(this).find( "form" ).on( "submit", function( event ) {
				event.preventDefault();
				addNewAlert();
			});
			$("<option />", {text: "--- select storage ---" , value: ""}).appendTo($( "#storagesel"));
			$("<option />", {text: "--- select volume ---" , value: ""}).appendTo($( "#volumesel"));
			$.each(fleet, function(i, val) {
				if (val.VOLUME) {
					// $("<option />", {text: val , value: val, selected: (oParams.storage == val)}).appendTo($( "#storagesel"));
					$("<option />", {text: i , value: i}).appendTo($( "#storagesel"));
				}
			});
			$( "#storagesel" ).change(function(event, data) {
				$( "#volumesel").empty();
				$("<option />", {text: "--- select volume ---" , value: "", selected: true}).appendTo($( "#volumesel"));
				$.each(fleet[event.target.value]["VOLUME"], function(i, val) {
					$("<option />", {text: val , value: val}).appendTo($( "#volumesel"));
				});
			});
			if (oParams.storage) {
				$( "#volumesel").empty();
				$("<option />", {text: "--- select volume ---" , value: "", selected: true}).appendTo($( "#volumesel"));
				if (fleet[oParams.storage]) {
					$( "#storagesel" ).val(oParams.storage);
					$.each(fleet[oParams.storage]['VOLUME'], function(i, val) {
						$("<option />", {text: val , value: val}).appendTo($( "#volumesel"));
					});
					// if (fleet[oParams.storage]["VOLUME"][oParams.volume] ) {
					$( "#volumesel" ).val(oParams.volume);
					// }
				}
			}
		},
		close: function() {
			$(this).find( "form" ).trigger('reset');
			var storage = $( "#storage" ),
			volume = $( "#volume" );
			allFields = $( [] ).add( storage ).add( volume );
			allFields.removeClass( "ui-state-error" );
			$(this).dialog("destroy");
		}
	});
}

function addNewAlert(title, oParams) {
	var valid= true,
	stor = $( "#storagesel" ).val(),
	vol = $( "#volumesel" ).val();
	if (! stor) {
		valid = false;
		updateTips("Storage has to be selected!");
	}
	if (! vol) {
		valid = false;
		updateTips("Volume has to be selected!");
	}

	if (valid) {
		$( "#alert-dialog-form" ).dialog( "close" );
		var $tree = $("#alrttree").fancytree("getTree");
		var newStore = {
			"title": stor,
			"folder": true,
			"expanded": true
		}
		var newVolume = {
			"title": vol,
			"folder": true,
			"expanded": true,
		}
		var child = {
			title: "",
			metric: "io",
			limit: "",
			peak: "",
			repeat: "",
			exclude: "",
			mailgrp: ""
		};
		var rootNode = $tree.getRootNode(),
		storNode = rootNode.findFirst(stor);
		if (! storNode) {
			storNode = rootNode.addNode(newStore, "child");
		}
		var volNode = storNode.findFirst(vol);
		if (! volNode) {
			volNode = storNode.addNode(newVolume, "child");
		}
		volNode.addNode(child, "child").setActive();
	}
	return valid;
}

var addNewAgrpDiv = '<div id="algrp-dialog-form"> \
  <p class="validateTips">All form fields are required.</p> \
  <form> \
    <fieldset> \
      <label for="mailgrpinp">E-mail group</label> \
      <input type="text" class="alrtcol" name="mailgrpinp" id="mailgrpinp" /><br> \
      <label for="mailinp" style="margin-top: 4px">E-mail</label> \
      <input type="text" class="alrtcol" name="mailinp" id="mailinp" style="margin-top: 4px" /> \
      <!-- Allow form submission with keyboard without duplicating the dialog button --> \
      <input type="submit" tabindex="-1" style="position:absolute; top:-1000px"> \
    </fieldset> \
  </form> \
</div>';

function addNewAgrpForm (title, oParams) {
	$( addNewAgrpDiv ).dialog({
		height: 280,
		width: 420,
		modal: true,
		title: title,
		buttons: {
			"Add new e-mail": addNewAlertMail,
			Cancel: function() {
				$(this).dialog("close");
			}
		},
		create: function() {
			alertForm = $(this).find( "form" ).on( "submit", function( event ) {
				event.preventDefault();
				addNewAlertMail();
			});
			if (oParams.storage) {
				$( "#mailgrpinp" ).val(oParams.storage);
			}
		},
		close: function() {
			$(this).find( "form" ).trigger('reset');
			var storage = $( "#mailgrpinp" ),
			volume = $( "#mailinp" );
			allFields = $( [] ).add( storage ).add( volume );
			allFields.removeClass( "ui-state-error" );
			$(this).dialog("destroy");
		}
	});
}

function addNewAlertMail(title, oParams) {
	var valid= true,
	emailRegex = /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/,
	mgrp = $( "#mailgrpinp" ),
	mgrpval = $( mgrp ).val(),
	mail = $( "#mailinp" ),
	mailval = $( mail ).val(),

	valid = valid && checkLength( mgrp, "E-mail group", 1, 32 );
	valid = valid && checkLength( mail, "mail", 3, 80 );

	valid = valid && checkRegexp( mgrp, /^[0-9a-z_\-]+$/i, "E-mail group name may consist of a-z, 0-9, dashes and underscores." );
	valid = valid && checkRegexp( mail, emailRegex, "This doesn't look like valid e-mail address" );

	if (valid) {
		$( "#algrp-dialog-form" ).dialog( "close" );
		var $tree = $("#alrtgrptree").fancytree("getTree");
		var newGrp = {
			"title": mgrpval,
			"folder": true,
			"expanded": true
		};
		var rootNode = $tree.getRootNode(),
		grpNode = rootNode.findFirst(mgrpval);
		if (! grpNode) {
			grpNode = rootNode.addNode(newGrp, "child");
		}
		var mailNode = grpNode.findFirst(mailval);
		if (! mailNode) {
			mailNode = grpNode.addChildren({ title: mailval });
			mailNode.setActive();
			mailGroups = $tree.toDict();
			$("#alrttree").fancytree("getTree").reload();
		}
	}
	return valid;
}
