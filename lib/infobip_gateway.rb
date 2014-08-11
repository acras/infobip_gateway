# encoding: UTF-8

require 'net/http'
require 'uri'
require 'rexml/document'

INFOBIP_SEND_URL = 'http://www.infobip.com/AddOn/SMSService/XML/XMLInput.aspx'

class InfobipSender
  attr_accessor :user, :password, :message_text, :sender, :encoding
  
  def initialize(encoding = nil)
    @recipients = []
    @encoding = encoding
  end
  
  def add_recipient(phone_number, message_id = nil)
    recipient_info = {:phone_number => phone_number}
    if message_id
      recipient_info[:message_id] = message_id
    end
    @recipients << recipient_info
  end
  
  def clear_recipients
    @recipients = []
  end
  
  def deliver
    url = URI.parse(INFOBIP_SEND_URL)
    req = Net::HTTP::Post.new(url.path)
    req.body = get_xml.strip
    res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      xml_data = res.body
      doc = REXML::Document.new(xml_data)
      doc.elements.each do |e|
        puts e.to_s
      end
    else
      false
      res.error!
    end
  end
  
  def get_xml
    x = <<-EOS
        XML=<SMS>
        <authentification>
          <username>#{@user}</username>
          <password>#{@password}</password>
        </authentification>
        <message>
          <sender>#{@sender}</sender>
    EOS
    if @encoding.nil?
      x << "<text>#{@message_text}</text>"
    elsif @encoding == "utf16"
      x << "<datacoding>8</datacoding>"
      x << "<binary>#{InfobipEncoder::to_utf16(@message_text)}</binary>"
    elsif @encoding == "gsm7"
      x << "<datacoding>0</datacoding>"
      x << "<binary>#{InfobipEncoder::to_gsm7(@message_text)}</binary>"
    end
    x += <<-EOS
        </message>
        <recipients>
          #{render_recipients}
        </recipients>
      </SMS>
    EOS
    x.strip
  end

  protected

  def render_recipients
    rec_text = ''
    @recipients.each do |rec|
      rec_text = rec_text + <<-EOS
        <gsm #{("messageId=\"" + rec[:message_id] + '"') if rec[:message_id]}>#{rec[:phone_number]}</gsm>
      EOS
    end
    rec_text
  end
end

class InfobipDeliveryChecker
  def get_delivery_statuses
    url = URI.parse('http://www.infobip.com/Addon/SMSService/XML/GetXMLDr.aspx?user=acrasbr&password=ricardo_8')
    req = Net::HTTP.get url
    
    doc = REXML::Document.new(req)
    res = []
    doc.elements.each do |elm|
      elm.elements.each do |eelm|
        res << {:id => eelm.attributes['id'], :status => eelm.attributes['status']} 
      end
    end
    puts res.inspect
    res
  end
end

# Codifica em hexadecimal a mensagem de acordo com o que o Infobip espera
class InfobipEncoder
  # mapeia unicode codepoint para GSM7 em hexa
  UNICODE_TO_GSM7_MAP = {
    0x0040	=> 0x00,	#	COMMERCIAL AT
    0x00A3	=> 0x01,	#	POUND SIGN
    0x0024	=> 0x02,	#	DOLLAR SIGN
    0x00A5	=> 0x03,	#	YEN SIGN
    0x00E8	=> 0x04,	#	LATIN SMALL LETTER E WITH GRAVE
    0x00E9	=> 0x05,	#	LATIN SMALL LETTER E WITH ACUTE
    0x00F9	=> 0x06,	#	LATIN SMALL LETTER U WITH GRAVE
    0x00EC	=> 0x07,	#	LATIN SMALL LETTER I WITH GRAVE
    0x00F2	=> 0x08,	#	LATIN SMALL LETTER O WITH GRAVE
    0x00E7	=> 0x09,	#	LATIN SMALL LETTER C WITH CEDILLA
    0x00C7	=> 0x09,	#	LATIN CAPITAL LETTER C WITH CEDILLA (redundância)
    0x000A	=> 0x0A,	#	LINE FEED
    0x00D8	=> 0x0B,	#	LATIN CAPITAL LETTER O WITH STROKE
    0x00F8	=> 0x0C,	#	LATIN SMALL LETTER O WITH STROKE
    0x000D	=> 0x0D,	#	CARRIAGE RETURN
    0x00C5	=> 0x0E,	#	LATIN CAPITAL LETTER A WITH RING ABOVE
    0x00E5	=> 0x0F,	#	LATIN SMALL LETTER A WITH RING ABOVE
    0x0394	=> 0x10,	#	GREEK CAPITAL LETTER DELTA
    0x005F	=> 0x11,	#	LOW LINE
    0x03A6	=> 0x12,	#	GREEK CAPITAL LETTER PHI
    0x0393	=> 0x13,	#	GREEK CAPITAL LETTER GAMMA
    0x039B	=> 0x14,	#	GREEK CAPITAL LETTER LAMDA
    0x03A9	=> 0x15,	#	GREEK CAPITAL LETTER OMEGA
    0x03A0	=> 0x16,	#	GREEK CAPITAL LETTER PI
    0x03A8	=> 0x17,	#	GREEK CAPITAL LETTER PSI
    0x03A3	=> 0x18,	#	GREEK CAPITAL LETTER SIGMA
    0x0398	=> 0x19,	#	GREEK CAPITAL LETTER THETA
    0x039E	=> 0x1A,	#	GREEK CAPITAL LETTER XI
    0x000C	=> 0x1B0A,	#	FORM FEED
    0x005E	=> 0x1B14,	#	CIRCUMFLEX ACCENT
    0x007B	=> 0x1B28,	#	LEFT CURLY BRACKET
    0x007D	=> 0x1B29,	#	RIGHT CURLY BRACKET
    0x005C	=> 0x1B2F,	#	REVERSE SOLIDUS
    0x005B	=> 0x1B3C,	#	LEFT SQUARE BRACKET
    0x007E	=> 0x1B3D,	#	TILDE
    0x005D	=> 0x1B3E,	#	RIGHT SQUARE BRACKET
    0x007C	=> 0x1B40,	#	VERTICAL LINE
    0x20AC	=> 0x1B65,	#	EURO SIGN
    0x00C6	=> 0x1C,	#	LATIN CAPITAL LETTER AE
    0x00E6	=> 0x1D,	#	LATIN SMALL LETTER AE
    0x00DF	=> 0x1E,	#	LATIN SMALL LETTER SHARP S (German)
    0x00C9	=> 0x1F,	#	LATIN CAPITAL LETTER E WITH ACUTE
    0x0020	=> 0x20,	#	SPACE
    0x0021	=> 0x21,	#	EXCLAMATION MARK
    0x0022	=> 0x22,	#	QUOTATION MARK
    0x0023	=> 0x23,	#	NUMBER SIGN
    0x00A4	=> 0x24,	#	CURRENCY SIGN
    0x0025	=> 0x25,	#	PERCENT SIGN
    0x0026	=> 0x26,	#	AMPERSAND
    0x0027	=> 0x27,	#	APOSTROPHE
    0x0028	=> 0x28,	#	LEFT PARENTHESIS
    0x0029	=> 0x29,	#	RIGHT PARENTHESIS
    0x002A	=> 0x2A,	#	ASTERISK
    0x002B	=> 0x2B,	#	PLUS SIGN
    0x002C	=> 0x2C,	#	COMMA
    0x002D	=> 0x2D,	#	HYPHEN-MINUS
    0x002E	=> 0x2E,	#	FULL STOP
    0x002F	=> 0x2F,	#	SOLIDUS
    0x0030	=> 0x30,	#	DIGIT ZERO
    0x0031	=> 0x31,	#	DIGIT ONE
    0x0032	=> 0x32,	#	DIGIT TWO
    0x0033	=> 0x33,	#	DIGIT THREE
    0x0034	=> 0x34,	#	DIGIT FOUR
    0x0035	=> 0x35,	#	DIGIT FIVE
    0x0036	=> 0x36,	#	DIGIT SIX
    0x0037	=> 0x37,	#	DIGIT SEVEN
    0x0038	=> 0x38,	#	DIGIT EIGHT
    0x0039	=> 0x39,	#	DIGIT NINE
    0x003A	=> 0x3A,	#	COLON
    0x003B	=> 0x3B,	#	SEMICOLON
    0x003C	=> 0x3C,	#	LESS-THAN SIGN
    0x003D	=> 0x3D,	#	EQUALS SIGN
    0x003E	=> 0x3E,	#	GREATER-THAN SIGN
    0x003F	=> 0x3F,	#	QUESTION MARK
    0x00A1	=> 0x40,	#	INVERTED EXCLAMATION MARK
    0x0041	=> 0x41,	#	LATIN CAPITAL LETTER A
    0x0042	=> 0x42,	#	LATIN CAPITAL LETTER B
    0x0043	=> 0x43,	#	LATIN CAPITAL LETTER C
    0x0044	=> 0x44,	#	LATIN CAPITAL LETTER D
    0x0045	=> 0x45,	#	LATIN CAPITAL LETTER E
    0x0046	=> 0x46,	#	LATIN CAPITAL LETTER F
    0x0047	=> 0x47,	#	LATIN CAPITAL LETTER G
    0x0048	=> 0x48,	#	LATIN CAPITAL LETTER H
    0x0049	=> 0x49,	#	LATIN CAPITAL LETTER I
    0x004A	=> 0x4A,	#	LATIN CAPITAL LETTER J
    0x004B	=> 0x4B,	#	LATIN CAPITAL LETTER K
    0x004C	=> 0x4C,	#	LATIN CAPITAL LETTER L
    0x004D	=> 0x4D,	#	LATIN CAPITAL LETTER M
    0x004E	=> 0x4E,	#	LATIN CAPITAL LETTER N
    0x004F	=> 0x4F,	#	LATIN CAPITAL LETTER O
    0x0050	=> 0x50,	#	LATIN CAPITAL LETTER P
    0x0051	=> 0x51,	#	LATIN CAPITAL LETTER Q
    0x0052	=> 0x52,	#	LATIN CAPITAL LETTER R
    0x0053	=> 0x53,	#	LATIN CAPITAL LETTER S
    0x0054	=> 0x54,	#	LATIN CAPITAL LETTER T
    0x0055	=> 0x55,	#	LATIN CAPITAL LETTER U
    0x0056	=> 0x56,	#	LATIN CAPITAL LETTER V
    0x0057	=> 0x57,	#	LATIN CAPITAL LETTER W
    0x0058	=> 0x58,	#	LATIN CAPITAL LETTER X
    0x0059	=> 0x59,	#	LATIN CAPITAL LETTER Y
    0x005A	=> 0x5A,	#	LATIN CAPITAL LETTER Z
    0x00C4	=> 0x5B,	#	LATIN CAPITAL LETTER A WITH DIAERESIS
    0x00D6	=> 0x5C,	#	LATIN CAPITAL LETTER O WITH DIAERESIS
    0x00D1	=> 0x5D,	#	LATIN CAPITAL LETTER N WITH TILDE
    0x00DC	=> 0x5E,	#	LATIN CAPITAL LETTER U WITH DIAERESIS
    0x00A7	=> 0x5F,	#	SECTION SIGN
    0x00BF	=> 0x60,	#	INVERTED QUESTION MARK
    0x0061	=> 0x61,	#	LATIN SMALL LETTER A
    0x0062	=> 0x62,	#	LATIN SMALL LETTER B
    0x0063	=> 0x63,	#	LATIN SMALL LETTER C
    0x0064	=> 0x64,	#	LATIN SMALL LETTER D
    0x0065	=> 0x65,	#	LATIN SMALL LETTER E
    0x0066	=> 0x66,	#	LATIN SMALL LETTER F
    0x0067	=> 0x67,	#	LATIN SMALL LETTER G
    0x0068	=> 0x68,	#	LATIN SMALL LETTER H
    0x0069	=> 0x69,	#	LATIN SMALL LETTER I
    0x006A	=> 0x6A,	#	LATIN SMALL LETTER J
    0x006B	=> 0x6B,	#	LATIN SMALL LETTER K
    0x006C	=> 0x6C,	#	LATIN SMALL LETTER L
    0x006D	=> 0x6D,	#	LATIN SMALL LETTER M
    0x006E	=> 0x6E,	#	LATIN SMALL LETTER N
    0x006F	=> 0x6F,	#	LATIN SMALL LETTER O
    0x0070	=> 0x70,	#	LATIN SMALL LETTER P
    0x0071	=> 0x71,	#	LATIN SMALL LETTER Q
    0x0072	=> 0x72,	#	LATIN SMALL LETTER R
    0x0073	=> 0x73,	#	LATIN SMALL LETTER S
    0x0074	=> 0x74,	#	LATIN SMALL LETTER T
    0x0075	=> 0x75,	#	LATIN SMALL LETTER U
    0x0076	=> 0x76,	#	LATIN SMALL LETTER V
    0x0077	=> 0x77,	#	LATIN SMALL LETTER W
    0x0078	=> 0x78,	#	LATIN SMALL LETTER X
    0x0079	=> 0x79,	#	LATIN SMALL LETTER Y
    0x007A	=> 0x7A,	#	LATIN SMALL LETTER Z
    0x00E4	=> 0x7B,	#	LATIN SMALL LETTER A WITH DIAERESIS
    0x00F6	=> 0x7C,	#	LATIN SMALL LETTER O WITH DIAERESIS
    0x00F1	=> 0x7D,	#	LATIN SMALL LETTER N WITH TILDE
    0x00FC	=> 0x7E,	#	LATIN SMALL LETTER U WITH DIAERESIS
    0x00E0	=> 0x7F	  # LATIN SMALL LETTER A WITH GRAVE
  }
  # from deve estar em alguma codificação unicode (UTF8 ou UTF16)
  # assume que não existem caracteres inválidos em from
  def self.to_gsm7(from)
    from.each_codepoint.collect {|c| sprintf "%02X", (UNICODE_TO_GSM7_MAP[c] or 0x20) }.join
  end
  def self.to_utf16(from)
    from.encode("UTF-16BE").each_byte.collect {|b| sprintf "%02X",b }.join
  end
end
