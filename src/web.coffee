drawFacepile = (data) ->
    friends_of_consumers = {}
    user_data_to_display = (ids) ->
        FB.api
            method: 'fql.query'
            query: """
                  SELECT uid, name, pic_square FROM user WHERE uid IN (#{ids.toString()})
                  """,
            (data) ->
                merge = (friend) ->
                    $.extend friends_of_consumers[friend.uid], friend
                merge(friend) for friend in data
                debugger

    FB.api
        method: 'fql.multiquery'
        queries:
            friends: """
                     SELECT uid, name, pic_square FROM user WHERE uid IN 
                     (SELECT uid2 FROM friend WHERE 
                              uid1 = me() and 
                              uid2 != me() and 
                              uid2 in (#{data.ids.toString()}))
                    """
            friends_of_friends: """
                    SELECT uid, name, pic_square FROM user WHERE uid IN 
                          (SELECT uid,mutual_friend_count FROM user WHERE 
                              mutual_friend_count > 0
                              and uid != me() 
                              and uid IN(#{data.ids.toString()}))
                    """
        (data) ->
            mutual_friends_data = (fb_ids) ->
                id2query = (id) ->
                    method: 'GET'
                    relative_url: "me/mutualfriends/#{id}"
                FB.api '/', 'POST',
                    batch: (id2query id for id in fb_ids),
                    (data) ->
                        fill = (uid, mutual_friends) ->
                            add = (consumer_id, friend_id) ->
                                if not friends_of_consumers[friend_id]
                                    friends_of_consumers[friend_id] =
                                        friends: []
                                
                                friends_of_consumers[friend_id].friends.push consumer_id
                            add(uid, friend.id) for friend in mutual_friends

                        fill(fb_ids[i], JSON.parse(mutual_friends.body).data) for mutual_friends, i in data
                        user_data_to_display(id for id of friends_of_consumers)


            [friends_and_consumers, fofs_and_consumers] = (x.fql_result_set for x in data)
            friends_and_consumers = friends_and_consumers.map (x) ->
                  x.isConsumer = true
                  x
            fofs_and_consumers = fofs_and_consumers[0..49] #limit to 50 as it is the limit for batch request to FB
            mutual_friends_data fofs_and_consumers.map (x) -> x.uid
    $('#helpful-friends-list').html(data.list)
    $('#helpful-friends-title .right').html(data.title)
    $('.helpful-friend').tooltipster #http://calebjacob.com/tooltipster
        theme: '.my-custom-theme',
        position: 'top',
        maxWidth: 387,
        interactive: true,
        #interactiveAutoClose: false,
        offsetY: -40
    $('#login-invite').hide(500)
    $('#facepile').show(500)

express = require("express")
logfmt = require("logfmt")
app = express()
app.use logfmt.requestLogger()
app.get "/", (req, res) ->
  res.send "Hello My World!"

app.get "/facepile", (req, res) ->
  batchFbQuery req.query.token, [], (data) ->
    res.send data


port = process.env.PORT or 5000
app.listen port, ->
  console.log "Listening on " + port

https = require("https")
batchFbQuery = (token, queries, callback) ->
  console.log token
  url = "/?access_token=" + token + "&api_key=532945086745127"
  batch = [
    method: "GET"
    relative_url: "/me/friends"
  ,
    method: "GET"
    relative_url: "/me"
  ]
  url = url + "&batch=" + JSON.stringify(batch)
  console.log url
  options =
    host: "graph.facebook.com"
    path: url
    method: "POST"

  req = https.request(options, (res) ->
    console.log "STATUS: " + res.statusCode
    console.log "HEADERS: " + JSON.stringify(res.headers)
    res.setEncoding "utf8"
    body = ""
    res.on "data", (chunk) ->
      
      # console.log("body:" + chunk);
      body += chunk

    res.on "end", (tt) ->
      callback body

  )
  req.on "error", (e) ->
    console.log "problem with request: " + e.message

  req.end()

