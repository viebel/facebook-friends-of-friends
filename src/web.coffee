`// web.js
var express = require("express");
var logfmt = require("logfmt");
var app = express();

app.use(logfmt.requestLogger());

app.get('/', function(req, res) {
  res.send('Hello My World!');
});

app.get('/facepile', function(req, res) {
    batchFbQuery(req.query.token, [], function(data){
        res.send(data);
    });
});
var port = process.env.PORT || 5000;
app.listen(port, function() {
  console.log("Listening on " + port);
});

var https = require('https');
function batchFbQuery(token, queries, callback) {
    console.log(token);
    var url = '/?access_token='+ token,
    batch=[{
     "method":"GET",
     "relative_url": "/me/friends"
      }, {
      "method": "GET",
      "relative_url": "/me" 
    }];
    url = url + '&batch=' + JSON.stringify(batch);
    console.log(url);

    var options = {
          host:'graph.facebook.com',
          path:url,
          method: 'POST'
       };



     var req = https.request(options, function(res){
       console.log('STATUS: ' + res.statusCode);
       console.log('HEADERS: ' + JSON.stringify(res.headers));
       res.setEncoding('utf8');
       var body='';
       res.on('data', function(chunk){
      // console.log("body:" + chunk);
          body += chunk;

        });
       res.on('end', function(tt){
          callback(body);
       });
    });

     req.on('error', function(e) {
          console.log('problem with request: ' + e.message);

     });


     req.end();
}`
