_ = require 'underscore'
httpGet = (host, path, callback) ->
    http = require("http")
    options =
       host: host
       path: path
       method: "GET"
    req = http.request options, (res) ->
       res.setEncoding "utf8"
       data = ""
       res.on "data", (chunk) ->
         data += chunk
       res.on "end", ->
         callback data
    req.on "error", (e) ->
       console.log "problem with request: " + e.message
       callback "We have encounter an issue"
    req.end()
facepile = (consumer_fb_ids, token, response_callback) ->
    FB = require 'fb'
    FB.setAccessToken token
    FB.options
       appSecret: '532945086745127'
    friends_of_consumers = {}
    user_data_to_display = (ids, callback) ->
        FB.api
            method: 'fql.query'
            query: """
                  SELECT uid, name, pic_square FROM user WHERE uid IN (#{ids.toString()})
                  """,
            callback

    mutual_friends_data = (fb_ids, names) ->
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

                fill(names[i], JSON.parse(mutual_friends.body).data) for mutual_friends, i in data
                user_data_to_display (id for id of friends_of_consumers), (data) ->
                    helpful_friends = (_.extend {}, f, friends_of_consumers[f.uid] for f in data)
                    response_callback helpful_friends

    FB.api
        method: 'fql.multiquery'
        queries:
            friends: """
                     SELECT uid, name, pic_square FROM user WHERE uid IN 
                     (SELECT uid2 FROM friend WHERE 
                              uid1 = me() and 
                              uid2 != me() and 
                              uid2 in (#{consumer_fb_ids.toString()}))
                    """
            friends_of_friends: """
                    SELECT uid, name, pic_square FROM user WHERE uid IN 
                          (SELECT uid,mutual_friend_count FROM user WHERE 
                              mutual_friend_count > 0
                              and uid != me() 
                              and uid IN(#{consumer_fb_ids.toString()}))
                    """
        (data) ->
            [friends_and_consumers, fofs_and_consumers] = (x.fql_result_set for x in data)
            friends_and_consumers = friends_and_consumers.map (x) ->
                  x.isConsumer = true
                  x
            fofs_and_consumers = fofs_and_consumers[0..49] #limit to 50 as it is the limit for batch request to FB
            mutual_friends_data((x.uid for x in fofs_and_consumers), (x.name for x in fofs_and_consumers))

consumer_fb_ids_of_merchant = (merchantId, callback) ->
    httpGet "plugins.shefing.com", "/consumers/facepile_me.json?merchantId=#{merchantId}", callback
                

express = require("express")
logfmt = require("logfmt")
app = express()
app.use logfmt.requestLogger()
app.get "/", (req, res) ->
  res.send "Hello My World!"

app.get "/facepile", (req, res) ->
  consumer_fb_ids_of_merchant req.query.merchantId, (fb_ids) ->
      console.log "fb_ids: #{fb_ids}"
      facepile JSON.parse(fb_ids), req.query.token, (data) ->
        res.send JSON.stringify data


port = process.env.PORT or 5000
app.listen port, ->
  console.log "Listening on " + port

