var express = require('express');
var url = require('url');
var fs = require('fs');
var qlikauth = require('qlik-auth');
var google = require('googleapis');

var api = google.oauth2('v2');
var OAuth2 = google.auth.OAuth2;

// Settings for creating https web server
// var http = require('http');
var https = require('https');
var options = {
  key: fs.readFileSync(__dirname + 'key.key'),
  cert: fs.readFileSync(__dirname + 'crt.crt'),
  ca: [
    fs.readFileSync(__dirname + 'crt.crt'), 
    fs.readFileSync(__dirname + 'anothercrt.crt'), 
    fs.readFileSync(__dirname + 'anothercrt.crt')
  ]
};   // read certificates in here

var app = express();
var arg = process.argv.slice(2);
var settings = {};


arg.forEach(function(a) {
    var key = a.split("=");
  switch(key[0]) {
      case "domain":
        settings.domain = key[1];
        break;
      case "user_directory":
        settings.userDirectory = key[1];
        break;
      case "client_id":
        settings.clientId = key[1];
        break;
      case "client_secret":
        settings.clientSecret = key[1];
        break;
      case "redirect_uris":
        settings.redirectUri = key[1];
        settings.port = url.parse(settings.redirectUri).port || 80
        settings.path = url.parse(settings.redirectUri).path || "/oauth2callback"
        break;
  }
});

//Create oauth2 client
oauth2Client = new OAuth2(settings.clientId, settings.clientSecret, settings.redirectUri);

app.get('/', function (req, res) {
  qlikauth.init(req, res);
  //Generate authentication url with email scope
  var authUrl = oauth2Client.generateAuthUrl({
    access_type: 'online',
    scope: 'email'
  });

  //Redirect to generated url
  res.redirect(authUrl);
});

app.get(settings.path, function (req, res) {
  //Get token from returned code parameter
  oauth2Client.getToken(req.query.code, function(err, token) {
    if (err) {res.send(err); return};

    //Set credentials from token
    oauth2Client.setCredentials(token);

    //Get user details
    api.userinfo.get({ auth: oauth2Client }, function(err, response) {
      if (err) {res.send(err); return};

      //Make sure authenticated user belongs to the right domain
      if(!response.email.endsWith(settings.domain)) {
        res.send("Invalid domain address");
        return;
      }

      //Define user directory, user identity and attributes
      var profile = {
        'UserDirectory': settings.userDirectory, 
        'UserId': response.email,
        'Attributes': []
      }

      //Make call for ticket request
      qlikauth.requestTicket(req, res, profile);
    });
  });
});

//Create web server
// var server = http.createServer(app).listen(settings.port, function() {});
var server = https.createServer(options, app).listen(settings.port, function() {
//  console.log('HTTPS started successfully');
});

String.prototype.endsWith = function(suffix) {
    return this.indexOf(suffix, this.length - suffix.length) !== -1;
};
