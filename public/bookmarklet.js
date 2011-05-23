(function(url) {
  var Ajax = {}

  /*!
    * Reqwest! A x-browser general purpose XHR connection manager
    * copyright Dustin Diaz 2011
    * https://github.com/ded/reqwest
    * license MIT
    */
  !function (target) {
    var twoHundo = /^20\d$/,
        doc = document,
        byTag = 'getElementsByTagName',
        topScript = doc[byTag]('script')[0],
        head = topScript.parentNode,
        xhr = ('XMLHttpRequest' in window) ?
          function () {
            return new XMLHttpRequest();
          } :
          function () {
            return new ActiveXObject('Microsoft.XMLHTTP');
          };

    var uniqid = 0;

    function readyState(o, success, error) {
      return function () {
        if (o && o.readyState == 4) {
          if (twoHundo.test(o.status)) {
            success(o);
          } else {
            error(o);
          }
        }
      };
    }

    function setHeaders(http, options) {
      var headers = options.headers || {};
      headers.Accept = 'text/javascript, text/html, application/xml, text/xml, */*';
      if (options.data) {
        headers['Content-type'] = 'application/x-www-form-urlencoded';
        for (var h in headers) {
          headers.hasOwnProperty(h) && http.setRequestHeader(h, headers[h], false);
        }
      }
    }

    function getCallbackName(o) {
      var callbackVar = o.jsonpCallback || "callback";
      if (o.url.substr(-(callbackVar.length + 2)) == (callbackVar + "=?")) {
        // Generate a guaranteed unique callback name
        var callbackName = "reqwest_" + uniqid++;

        // Replace the ? in the URL with the generated name
        o.url = o.url.substr(0, o.url.length - 1) + callbackName;
        return callbackName;
      } else {
        // Find the supplied callback name
        var regex = new RegExp(callbackVar + "=([\\w]+)");
        return o.url.match(regex)[1];
      }
    }

    function getRequest(o, fn, err) {
      if (o.type == 'jsonp') {
        var script = doc.createElement('script');

        // Add the global callback
        var callbackName = getCallbackName(o);
        target[callbackName] = function (data) {
          // Call the success callback
          o.success && o.success(data);
        };

        // Setup our script element
        script.type = "text/javascript";
        script.src = o.url;
        script.async = true;
        script.onload = function () {
          // Script has been loaded, and thus the user callback has
          // been called, so lets clean up now.
          head.removeChild(script);
          delete target[callbackName];
        };

        // Add the script to the DOM head
        head.insertBefore(script, topScript);
      } else {
        var http = xhr();
        http.open(o.method || 'GET', typeof o == 'string' ? o : o.url, true);
        setHeaders(http, o);
        http.onreadystatechange = readyState(http, fn, err);
        o.before && o.before(http);
        http.send(o.data || null);
        return http;
      }
    }

    function Reqwest(o, fn) {
      this.o = o;
      this.fn = fn;
      init.apply(this, arguments);
    }

    function setType(url) {
      if (/\.json$/.test(url)) {
        return 'json';
      }
      if (/\.jsonp$/.test(url)) {
        return 'jsonp';
      }
      if (/\.js$/.test(url)) {
        return 'js';
      }
      if (/\.html?$/.test(url)) {
        return 'html';
      }
      if (/\.xml$/.test(url)) {
        return 'xml';
      }
      return 'js';
    }

    function init(o, fn) {
      this.url = typeof o == 'string' ? o : o.url;
      this.timeout = null;
      var type = o.type || setType(this.url), self = this;
      fn = fn || function () {};

      if (o.timeout) {
        this.timeout = setTimeout(function () {
          self.abort();
          error();
        }, o.timeout);
      }

      function complete(resp) {
        o.complete && o.complete(resp);
      }

      function success(resp) {
        o.timeout && clearTimeout(self.timeout) && (self.timeout = null);
        var r = resp.responseText;

        switch (type) {
        case 'json':
          resp = eval('(' + r + ')');
          break;
        case 'js':
          resp = eval(r);
          break;
        case 'html':
          resp = r;
          break;
        // default is the response from server
        }

        fn(resp);
        o.success && o.success(resp);
        complete(resp);
      }

      function error(resp) {
        o.error && o.error(resp);
        complete(resp);
      }

      this.request = getRequest(o, success, error);
    }

    Reqwest.prototype = {
      abort: function () {
        this.request.abort();
      },

      retry: function () {
        init.call(this, this.o, this.fn);
      }
    };

    function reqwest(o, fn) {
      return new Reqwest(o, fn);
    }

    function enc(v) {
      return encodeURIComponent(v);
    }

    function serial(el) {
      var n = el.name;
      // don't serialize elements that are disabled or without a name
      if (el.disabled || !n) {
        return '';
      }
      n = enc(n);
      switch (el.tagName.toLowerCase()) {
      case 'input':
        switch (el.type) {
        // silly wabbit
        case 'reset':
        case 'button':
        case 'image':
        case 'file':
          return '';
        case 'checkbox':
        case 'radio':
          return el.checked ? n + '=' + (el.value ? enc(el.value) : true) + '&' : '';
        default: // text hidden password submit
          return n + '=' + (el.value ? enc(el.value) : true) + '&';
        }
        break;
      case 'textarea':
        return n + '=' + enc(el.value) + '&';
      case 'select':
        // @todo refactor beyond basic single selected value case
        return n + '=' + enc(el.options[el.selectedIndex].value) + '&';
      }
      return '';
    }

    reqwest.serialize = function (form) {
      var inputs = form[byTag]('input'),
          selects = form[byTag]('select'),
          texts = form[byTag]('textarea');
      return (v(inputs).chain().toArray().map(serial).value().join('') +
      v(selects).chain().toArray().map(serial).value().join('') +
      v(texts).chain().toArray().map(serial).value().join('')).replace(/&$/, '');
    };

    reqwest.serializeArray = function (f) {
      for (var pairs = this.serialize(f).split('&'), i = 0, l = pairs.length, r = [], o; i < l; i++) {
        pairs[i] && (o = pairs[i].split('=')) && r.push({name: o[0], value: o[1]});
      }
      return r;
    };

    var old = target.reqwest;
    reqwest.noConflict = function () {
      target.reqwest = old;
      return this;
    };

    // defined as extern for Closure Compilation
    // do not change to (dot) '.' syntax
    target['reqwest'] = reqwest;

  }(Ajax);

  var reqwest = Ajax.reqwest;

  var log = function(message) {
    if ((typeof console != "undefined" && console !== null) && (console.log != null)) {
      console.log("** kindlebility **\t" + message);
    }
  };

  var body = document.getElementsByTagName('body')[0];
  var div = document.getElementById('kindlebility');
  var host = div.getAttribute('data-host');
  var to = div.getAttribute('data-email');
  var notify = function(message) {
    div.innerHTML = message;
    div.appendChild(document.createTextNode(' '));
  };

  // TODO: Some sort of detection of a failure
  var kindlebility = function() {
    var params = "?url=" + encodeURIComponent(url) + "&email=" + encodeURIComponent(to);
    reqwest({
      url: "http://" + host + "/ajax/submit.json" + params,
      type: 'json',
      success: function(submit) {
        notify(submit.message);
        if (submit.limited) {
          setTimeout(function() {
            body.removeChild(div);
          }, 2500);
          return;
        }
        var id = submit.id;
        var timer = setInterval(function() {
          reqwest({
            url: "http://" + host + "/ajax/status/" + id + ".json",
            type: 'json',
            success: function(status) {
              notify(status.message);
              if (status.done) {
                setTimeout(function() {
                  body.removeChild(div);
                }, 2500);
                clearInterval(timer);
              }
            }
          })
        }, 500);
      }
    });
  };

  if ((window.location.protocol + "//" + window.location.host + "/") == url) {
    alert("You need to run this on an article page! Main or home pages don't work very well.")
  } else {
    kindlebility();
  }
})(document.location.href);
