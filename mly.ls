require! <[crypto optimist]>
require! \./lib/util
{member,ad} = optimist.argv

members = require "./data/twly/merged.json"

party = -> match it
| \中國國民黨     => \KMT
| \民主進步黨     => \DPP
| \台灣團結聯盟   => \TSU
| \無黨團結聯盟   => \NSU
| \親民黨         => \PFP
| \新黨           => \NP
| \建國黨         => \TIP
| \超黨派問政聯盟 => \CPU
| \民主聯盟       => \DU
| \新國家陣線     => \NNA
| /無(黨籍)?/     => null
| \其他           => null
else => console.error it

city = -> match it.replace /台/g, '臺' # ISO-3166-2:TW
| \新北市 => \TPQ
| \臺北市 => \TPE
| \臺中市 => \TXG
| \臺南市 => \TNN
| \高雄市 => \KHH
| \基隆市 => \KEE
| \新竹市 => \HSZ
| \嘉義市 => \CYI
| \桃園縣 => \TAO
| \新竹縣 => \HSQ
| \苗栗縣 => \MIA
| \彰化縣 => \CHA
| \南投縣 => \NAN
| \雲林縣 => \YUN
| \嘉義縣 => \CYQ
| \屏東縣 => \PIF
| \宜蘭縣 => \ILA
| \花蓮縣 => \HUA
| \臺東縣 => \TTT
| \澎湖縣 => \PEN
| \高雄縣 => \KHQ
| \臺南縣 => \TNQ
| \臺北縣 => \TPQ
| \臺中縣 => \TXQ
| \金門縣 => \JME # no ISO3166, use GB/T 2260-2002
| \連江縣 => \LJF # no ISO3166, use GB/T 2260-2002
else => console.error it

constituency = -> match it
| /^.*(市|縣)$/ => [ city(it), 0 ]
| /(.*(?:市|縣))(?:第(\S+))?選舉區/ =>
    area = that.2
    [ city(that.1), if area? => util.intOfZHNumber area else 0 ]
| /(平地|山地)原住民/ => [\aborigine, if that.1 is '平地' => \lowland else \highland]
| /全國不分區/        => <[proportional]>
| /僑居國外國民|僑選/ => <[foreign]>
else => console.error it

console.error members.length

res = members.map (m) ->
  id = m.uid
  for m_et in m.each_term
    key = crypto.createHash('md5').update("MLY/#{m_et.name}", \utf8).digest('hex')
    m_et <<< do
      party: party m_et.party
      caucus: party m_et.caucus
      constituency: constituency m_et.constituency
      avatar: "http://avatars.io/50a65bb26e293122b0000073/#{key}"
      id: id
    m_et

res .= reduce (++)

if ad
  res .= filter (.ad is ad)

console.log JSON.stringify res, null, 4
