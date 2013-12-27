_ = require 'underscore'
pluralize = (n, singular, plural) ->
    if n > 1
        "#{n} #{plural}"
    else
        "#{n} #{singular}"
first_and_more = (array, n, str) ->
    if array.length <= n
        array
    else
        array[0...n-1].concat ["#{self.count - n} #{str}"]
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
            if data.error_msg?
                response_callback(data.error_msg)
                console.log "error in fql.multiquery: #{JSON.stringify data.error_msg}"
                return
            [friends_and_consumers, fofs_and_consumers] = (x.fql_result_set for x in data)
            friends_and_consumers = friends_and_consumers.map (x) ->
                  x.isConsumer = true
                  x
            fofs_and_consumers = fofs_and_consumers[0..49] #limit to 50 as it is the limit for batch request to FB
            mutual_friends_data((x.uid for x in fofs_and_consumers), (x.name for x in fofs_and_consumers))

consumer_fb_ids_of_merchant = (merchantId, callback) ->
    httpGet "plugins.shefing.com", "/merchants/#{merchantId}/consumer_fb_ids.json?", callback
                

express = require("express")
logfmt = require("logfmt")
app = express()
app.use logfmt.requestLogger()
app.get "/", (req, res) ->
  res.send "Hello My World!"
app.get "/facepile", (req, res) ->
  consumer_fb_ids_of_merchant req.query.merchantId, (fb_ids) ->
      add_helpful_sentence = (friend) ->
          sentence = ->
             my_friends_sentence = (friends, me_also)->
                friends_list = ->
                    first_and_more(friends, 5, 'autres').toString()#to_sentence( :two_words_connector => ' et ', :last_word_connector => ' et ')
                singular = if me_also then 'sommes des clients' else 'est un client'
                plural = if me_also then 'sommes des clients' else 'sont des clients'
                "#{pluralize(friends.length, "de mes amis #{singular}", "de mes amis #{plural}")} de [[MERCHANT_NAME]]: #{friends_list friend.friends}"
             if friend.friends?
                if friend.isConsumer?
                  "Moi, ainsi que #{my_friends_sentence(friend.friends, true)}"
                else
                  my_friends_sentence(friend.friends, false)
             else
                "Je suis un client de [[MERCHANT_NAME]]"
          sentence: sentence()
      try
          facepile JSON.parse(fb_ids), req.query.token, (helpful_friends) ->
              helpful_friends_with_sentence = (_.extend {}, f, add_helpful_sentence f for f in helpful_friends)
              res.send JSON.stringify helpful_friends_with_sentence
      catch error
            res.send "error"
            console.log "Exception in the callback of consumer_fb_ids_of_merchant: #{error}"


port = process.env.PORT or 5000
app.listen port, ->
  console.log "Listening on " + port

