require! {marked, fs, optimist}
require! \./lib/util
require! \./lib/ly


class MarkdownToJsonParser
    ->
        marked.setOptions {+gfm, -pedantic, +sanitize}
        @reset!

    reset: ->
        @ast = [{}]  # node := [ params, ...nodes ]
        @current_node = @ast
        @stack = []

    to-json: (filename) ->
        @reset!
        for token in marked.lexer util.readFileSync filename
            @consume-token token
        @ast

    consume-token: (token) ->
        switch token.type
        | \heading =>
            # {"type":"heading","depth":1,"text":"院會紀錄"}
            if token.depth > @stack.length
                if token.depth != @stack.length + 1
                    @err_token "(>) #{token.depth} != #{@stack.length} + 1", token
                @current_node.push [ { section: token.text } ]
                @stack.push @current_node
                @current_node = @current_node[*-1]
            else if token.depth < @stack.length
                @stack.length = token.depth - 1
                parent = @stack[*-1]
                @current_node = [ { section: token.text } ]
                @stack.push @current_node
                parent.push @current_node
            else
                if @stack.length == 0
                    @err_token "(=) #{@stack.length}", token
                @current_node = [ { section: token.text } ]
                parent = @stack[*-1]
                parent.push @current_node
        | \space =>
            # {"type":"space"}
        | \code =>
            # {"type":"code","lang":"json","text":"{[null]}"}
            @current_node[0] <<< JSON.parse token.text
        | \paragraph, \text =>
            # {"type":"paragraph","text":"主席：現在開會，進行報告事項。\n\n\n"}
            text = token.text - /\n/g
            @current_node.push text
        | \loose_item_start, \list_item_start =>
            # {"type":"loose_item_start"}
            @current_node.push [{}]
            @stack.push @current_node
            @current_node = @current_node[*-1]
        | \list_item_end =>
            # {"type":"list_item_end"}
            @current_node = @stack.pop!
        | \list_start =>
            # {"type":"list_start","ordered":true}
            @current_node.push [ { token.ordered } ]
            @stack.push @current_node
            @current_node = @current_node[*-1]
        | \list_end =>
            # {"type":"list_end"}
            @current_node = @stack.pop!
        | \blockquote_start =>
            @current_node.push token  # TODO
        | \blockquote_end =>
            @current_node.push token  # TODO
        | _ =>
            @current_node.push token

    err_token: (msg, token) ->
        console.error "Unexpected token: #msg =>" + JSON.stringify token


class LyMarkdownToJsonParser extends MarkdownToJsonParser
    ->
        @lastSpeaker = null

    consume-token: (token) ->
        switch token.type
        | \paragraph, \text =>
            match token.text
            | /^(\S+?)：\s*(.*)/ =>
                [speaker, content] = that[1 to 2]
                @lastSpeaker = speaker
            | _ =>
                speaker = @lastSpeaker || undefined
                content = token.text - /^\s*/ - /\s*$/

            match content
            | /[\s*（(](\d+時\d+分)[）)]\s*/ =>
                content = content.replace that.0, ''
                time = that.1
            @current_node.push {speaker, content, time}
        | _ => super ...


{gazette, ad, dir = '.', text, fromtext} = optimist.argv

ly.forGazette gazette, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    return if ad and g.ad !~= ad

    console.log ">>> #id"
    parser = new LyMarkdownToJsonParser
    ast = parser.to-json "#dir/#id.md"
    fs.writeFileSync "#dir/#id.json", JSON.stringify(ast, '', 4)
