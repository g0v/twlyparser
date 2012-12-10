require! {marked}
require! \./lib/util

md = util.readFileSync "raw/3445.md"

ast = [{}]  # node := [ params, ...nodes]
current_node = ast
stack = []

err_token = (token) -> console.error "Unexpected token: " + JSON.stringify token

marked.setOptions \
    {gfm: true, pedantic: false, sanitize: true}

for token in marked.lexer md
    switch token.type
    | \heading =>
        # {"type":"heading","depth":1,"text":"院會紀錄"}
        if token.depth > stack.length
            if token.depth != stack.length + 1
                err_token token
                break
            current_node.push [ { section: token.text } ]
            stack.push current_node
            current_node = current_node[*-1]
        else if token.depth < stack.length
            if token.depth != stack.length - 1
                err_token token
                break
            stack.pop!
            parent = stack[*-1]
            current_node = [ { text: token.text } ]
            stack.push current_node
            parent.push current_node
        else
            if stack.length == 0
                err_token token
            current_node = [ { text: token.text } ]
            parent = stack[*-1]
            parent.push current_node
    | \space =>
        # {"type":"space"}
        current_node.push '__space__'
    | \code =>
        # {"type":"code","lang":"json","text":"{[null]}"}
        current_node.push token
    | \paragraph =>
        # {"type":"paragraph","text":"主席：現在開會，進行報告事項。\n\n\n"}
        current_node.push token.text - /\n/g
    | \text =>
        # {"type":"text","text":" 主席：報告院會，議事錄已經宣讀完畢，沒有任何書面資料表示異議，因此議事錄確定。"}
        current_node.push token.text - /\n/g
    | \loose_item_start =>
        # {"type":"loose_item_start"}
        current_node.push token
    | \list_start =>
        # {"type":"list_start","ordered":true}
        current_node.push [ { token.ordered } ]
        stack.push current_node
        current_node = current_node[*-1]
    | \list_end =>
        # {"type":"list_end"}
        current_node = stack.pop!
    | \list_item_start =>
        # {"type":"list_item_start"}
        current_node.push token
    | \list_item_end =>
        # {"type":"list_item_end"}
        current_node.push token
    | _ =>
        console.log JSON.stringify token


console.log JSON.stringify ast, 'xx', 4
