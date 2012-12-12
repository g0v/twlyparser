require! {marked, fs, optimist}
require! \./lib/util
require! \./lib/ly


class MarkdownToJsonParser
    ->
        marked.setOptions {+gfm, -pedantic, +sanitize}
        @reset!

    reset: ->
        @ast = {data: []}
        @current = @ast
        @stack = [@current]

    to-json: (filename) ->
        @reset!
        for token in marked.lexer util.readFileSync filename
            @consume-token token
        @ast

    pop-from-stack: ->
        @stack.pop!
        @current = @stack[*-1]

    push-to-stack: (node) ->
        @stack[*-1].data.push node
        @current = node
        @stack.push @current

    append: (node) ->
        @current.data.push node

    consume-token: (token) ->
        switch token.type
        | \heading =>
            # {"type":"heading","depth":1,"text":"院會紀錄"}
            if token.depth > @stack.length - 1
                @push-to-stack { session: token.text, data: [] }
            else if token.depth < @stack.length - 1
                @stack.length = token.depth
                @push-to-stack { session: token.text, data: [] }
            else
                @pop-from-stack!
                @push-to-stack { session: token.text, data: [] }
        | \space =>
        | \code =>
            # {"type":"code","lang":"json","text":"{[null]}"}
            try
                json = token.text - /^```json/ - /```$/
                @append JSON.parse json
            catch
                @append { content: token.text, error: 'not-json' }
        | \paragraph, \text =>
            # {"type":"paragraph","text":"主席：現在開會，進行報告事項。\n\n\n"}
            text = token.text - /\n/g
            @append text
        | \loose_item_start, \list_item_start =>
            @push-to-stack { data: [] }
        | \list_start =>
            # {"type":"list_start","ordered":true}
            @push-to-stack { ordered: token.ordered, data: [] }
        | \list_item_end, \list_end =>
            @pop-from-stack!
        | \blockquote_start, \blockquote_end =>
            # not used for now
        | _ =>
            @append token

    err_token: (msg, token) ->
        console.error "Unexpected token: #msg =>" + JSON.stringify token


class LyMarkdownToJsonParser extends MarkdownToJsonParser
    ->
        super!
        @lastSpeaker = null

    consume-token: (token) ->
        switch token.type
        | \paragraph, \text =>
            match token.text
            | /^\s*([^：]{2,10})\s*：\s*(.*)\s*$/
                [speaker, content] = that[1 to 2]
                @lastSpeaker = speaker
            | _ =>
                speaker = @lastSpeaker || undefined
                content = token.text - /^\s*/ - /\s*$/

            match content
            | /[\s*（(](\d+時\d+分)[）)]\s*/ =>
                content = content.replace that.0, ''
                time = that.1
            @append {speaker, content, time}
        | \loose_item_start, \list_item_start, \list_item_end  =>
        | \list_end =>
            # promote to upper level to simplty the structure
            if @current.data.length == 1
                promote_node = @current.data[0]
                @pop-from-stack!
                @replace-last-node promote_node
        | _ => super ...

    replace-last-node: (node) ->
        @current.data[*-1] = node

    traverse: !(ast, visitor) ->
        visitor ast
        if ast.data
            for node in ast.data
                @traverse node, visitor
        # else

    to-json: ->
        ast = super ...
        # simplify item list structure when possible
        @traverse ast, (node) ->
            if node.session and node.data?.length == 1
                node <<<< node.data[0]
        ast

{gazette, ad, dir = '.', text, fromtext} = optimist.argv

ly.forGazette gazette, (id, g, type, entries, files) ->
    return if type isnt /院會紀錄/
    return if ad and g.ad !~= ad

    process.stdout.write id
    process.stdout.write '\r'

    parser = new LyMarkdownToJsonParser
    ast = parser.to-json "#dir/#id.md"
    fs.writeFileSync "#dir/#id.json", JSON.stringify(ast, '', 4)
