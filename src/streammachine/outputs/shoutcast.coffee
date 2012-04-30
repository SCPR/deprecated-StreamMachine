_u = require 'underscore'
icecast = require("icecast-stack")

module.exports = class Shoutcast
    constructor: (@stream,@req,@res) ->
        @id = null
                
        @reqIP      = req.connection.remoteAddress
        @reqPath    = req.url
        @reqUA      = req.headers?['user-agent']
        
        @stream.log.debug "request is in Shoutcast output", stream:@stream.key
        
        process.nextTick =>     
            # convert this into an icecast response
            @res = new icecast.IcecastWriteStack @res, @stream.options.meta_interval
            @res.queueMetadata StreamTitle:@stream.source.metaTitle, StreamUrl:@stream.source.metaURL
        
            headers = 
                "Content-Type":         "audio/mpeg"
                "Connection":           "close"
                "Transfer-Encoding":    "identity"
                "icy-name":             @stream.options.name
                "icy-metaint":          @stream.options.meta_interval
                        
            # write out our headers
            res.writeHead 200, headers
                
            @metaFunc = (data) =>
                if data.StreamTitle
                    @res.queueMetadata data

            @dataFunc = (chunk) => @res.write(chunk)
                
            # -- send a preroll if we have one -- #
        
            if @stream.preroll
                @stream.log.debug "making preroll request", stream:@stream.key
                @stream.preroll.pump @res, => @connectToStream()
            else
                @connectToStream()       
        
        # register our various means of disconnection
        @req.connection.on "end",   => @disconnect()
        @req.connection.on "close", => @disconnect()
        @res.connection.on "close", => @disconnect()
        
        @res.on "error", (err) =>
            console.log "got a response error for ", @id
        
        
    #----------
    
    disconnect: ->
        if @id
            @stream.closeListener @id
            @id = null
            
        @res?.end() unless (@res.stream?.connection?.destroyed || @res.connection?.destroyed)
    
    #----------
    
    connectToStream: ->
        unless @req.connection.destroyed
            # -- register our listener -- #
            @id = @stream.registerListener @, data:@dataFunc, meta:@metaFunc
        
    #----------
            
