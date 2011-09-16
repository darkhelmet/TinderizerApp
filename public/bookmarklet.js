(function(url) {
  var request = function(url, success) {
    if ('XDomainRequest' in window) {
      var xdr = new XDomainRequest();
      xdr.onload = function() {
        success(JSON.parse(xdr.responseText));
      };
      xdr.open('GET', url);
      xdr.send(null);
    } else {
      var xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState == 4) {
          success(JSON.parse(xhr.responseText));
        }
      };
      xhr.open('GET', url, true);
      xhr.setRequestHeader('Accept', 'application/json');
      xhr.send(null);
    }
  };

  var escapeRegex = function(text) {
    return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
  };

  var log = function(message) {
    if ((typeof console != "undefined" && console !== null) && (console.log != null)) {
      console.log("** Tinderizer **\t" + message);
    }
  };

  var body = document.getElementsByTagName('body')[0];
  var div = document.getElementById('Tinderizer') || document.getElementById('kindlebility');
  var host = div.getAttribute('data-host');
  var to = div.getAttribute('data-email');
  var notify = function(message) {
    div.innerHTML = message;
    div.appendChild(document.createTextNode(' '));
  };

  div.style.width = '300px';
  div.style.height = '30px';
  div.style.fontSize = '12px';

  // TODO: Some sort of detection of a failure
  var Tinderizer = function() {
    var params = "?url=" + encodeURIComponent(url) + "&email=" + encodeURIComponent(to) + "&t=" + (new Date()).getTime();
    request("http://" + host + "/ajax/submit.json" + params, function(submit) {
      notify(submit.message);
      if (submit.limited || !submit.id) {
        setTimeout(function() {
          body.removeChild(div);
        }, 2500);
        return;
      }
      var id = submit.id;
      var timer = setInterval(function() {
        request("http://" + host + "/ajax/status/" + id + ".json?t=" + (new Date()).getTime(), function(status) {
          notify(status.message);
          if (status.done) {
            setTimeout(function() {
              body.removeChild(div);
            }, 2500);
            clearInterval(timer);
          }
        });
      }, 500);
    });
  };

  var checks = {
    "You need to run this on an article page! Main or home pages don't work very well.": new RegExp(escapeRegex(window.location.protocol + "//" + window.location.host + "/") + '$'),
    'There is nothing to do on about:blank!': /about:blank/,
    'You need to run this on a publicly accessible HTML page!': /\.(pdf|jpg)$/i,
    'Run this on the raw page, not a Readability page!': /^https?:\/\/www.readability.com\/articles\//i
  };

  for (var message in checks) {
    if (checks.hasOwnProperty(message)) {
      if (checks[message].test(url)) {
        alert(message);
        body.removeChild(div);
        return;
      }
    }
  }

  Tinderizer();
})(document.location.href);
