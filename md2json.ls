require! {marked}
require! \./lib/util


class MarkdownToJsonParser
    ->
        marked.setOptions \
            {gfm: true, pedantic: false, sanitize: true}
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
                    err_token token
                    break
                @current_node.push [ { section: token.text } ]
                @stack.push @current_node
                @current_node = @current_node[*-1]
            else if token.depth < @stack.length
                if token.depth != @stack.length - 1
                    err_token token
                    break
                @stack.pop!
                parent = @stack[*-1]
                @current_node = [ { section: token.text } ]
                @stack.push @current_node
                parent.push @current_node
            else
                if @stack.length == 0
                    err_token token
                @current_node = [ { section: token.text } ]
                parent = @stack[*-1]
                parent.push @current_node
        | \space =>
            # {"type":"space"}
        | \code =>
            # {"type":"code","lang":"json","text":"{[null]}"}
            @current_node[0].data ||= {}
            @current_node[0].data <<< token
        | \paragraph =>
            # {"type":"paragraph","text":"主席：現在開會，進行報告事項。\n\n\n"}
            @current_node.push token.text - /\n/g
        | \text =>
            # {"type":"text","text":" 主席：報告院會，議事錄已經宣讀完畢，沒有任何書面資料表示異議，因此議事錄確定。"}
            text = token.text - /\n/g
            switch context
            | \loose_item =>
                #@current_node[*-1] = text + '\n'
                @current_node.push text
            | _ =>
                @current_node.push text
        | \loose_item_start, \list_item_start =>
            # {"type":"loose_item_start"}
            context = token.type - /_start/
            @current_node.push [{}]
            @stack.push @current_node
            @current_node = @current_node[*-1]
        | \list_item_end =>
            # {"type":"list_item_end"}
            @current_node = @stack.pop!
            context = null
        | \list_start =>
            # {"type":"list_start","ordered":true}
            @current_node.push [ { token.ordered } ]
            @stack.push @current_node
            @current_node = @current_node[*-1]
        | \list_end =>
            # {"type":"list_end"}
            @current_node = @stack.pop!
        | _ =>
            console.log JSON.stringify token

    err_token: (token) ->
        console.error "Unexpected token: " + JSON.stringify token


parser = new MarkdownToJsonParser
ast = parser.to-json 'raw/3445.md'

console.log JSON.stringify ast, '', 4
