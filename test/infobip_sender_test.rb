# encoding: UTF-8

require 'test/unit'
require '../lib/infobip_gateway.rb'
require 'rexml/document'

class TestInfobip < Test::Unit::TestCase
  def setup
    @user = 'user'
    @password = 'password'
    @sender = 'sender'
    @text = 'Message Text!'
    @mid1 = '1'
    @mpn1 = '554199743201'
    @mid2 = '2'
    @mpn2 = '554299720025'
  end
  def test_xml_generation_no_encoding
    @ib = InfobipSender.new
    @ib.user = @user
    @ib.password = @password
    @ib.sender = @sender
    @ib.message_text = @text
    @ib.add_recipient(@mpn1, @mid1)
    @ib.add_recipient(@mpn2, @mid2)
    expected_xml = <<-EOS
      XML=<SMS>
        <authentification>
          <username>#{@user}</username>
          <password>#{@password}</password>
        </authentification>
        <message>
          <sender>#{@sender}</sender>
          <text>#{@text}</text>
        </message>
        <recipients>
        <gsm messageId="#{@mid1}">#{@mpn1}</gsm>
        <gsm messageId="#{@mid2}">#{@mpn2}</gsm>
        </recipients>
      </SMS>
    EOS
    
    
    generated = @ib.get_xml.to_s.gsub(/ /,'').gsub(/\n/, '')
    expected = expected_xml.to_s.gsub(/ /,'').gsub(/\n/, '')
    
    assert_equal expected, generated
  end
  def test_xml_generation_gsm7
    @ib = InfobipSender.new "gsm7"
    @ib.user = @user
    @ib.password = @password
    @ib.sender = @sender
    @ib.message_text = @text
    @ib.add_recipient(@mpn1, @mid1)
    @ib.add_recipient(@mpn2, @mid2)
    expected_xml = <<-EOS
      XML=<SMS>
        <authentification>
          <username>#{@user}</username>
          <password>#{@password}</password>
        </authentification>
        <message>
          <sender>#{@sender}</sender>
          <datacoding>0</datacoding>
          <binary>#{InfobipEncoder::to_gsm7(@text)}</binary>
        </message>
        <recipients>
        <gsm messageId="#{@mid1}">#{@mpn1}</gsm>
        <gsm messageId="#{@mid2}">#{@mpn2}</gsm>
        </recipients>
      </SMS>
    EOS
    
    
    generated = @ib.get_xml.to_s.gsub(/ /,'').gsub(/\n/, '')
    expected = expected_xml.to_s.gsub(/ /,'').gsub(/\n/, '')
    
    assert_equal expected, generated
  end
  def test_xml_generation_utf16
    @ib = InfobipSender.new "utf16"
    @ib.user = @user
    @ib.password = @password
    @ib.sender = @sender
    @ib.message_text = @text
    @ib.add_recipient(@mpn1, @mid1)
    @ib.add_recipient(@mpn2, @mid2)
    expected_xml = <<-EOS
      XML=<SMS>
        <authentification>
          <username>#{@user}</username>
          <password>#{@password}</password>
        </authentification>
        <message>
          <sender>#{@sender}</sender>
          <datacoding>8</datacoding>
          <binary>#{InfobipEncoder::to_utf16(@text)}</binary>
        </message>
        <recipients>
        <gsm messageId="#{@mid1}">#{@mpn1}</gsm>
        <gsm messageId="#{@mid2}">#{@mpn2}</gsm>
        </recipients>
      </SMS>
    EOS
    
    
    generated = @ib.get_xml.to_s.gsub(/ /,'').gsub(/\n/, '')
    expected = expected_xml.to_s.gsub(/ /,'').gsub(/\n/, '')
    
    assert_equal expected, generated
  end
  def test_gsm7_encoding
    { "@ £ $ ¥ è é ù ì ò Ç ç \n Ø ø \r Å å Δ _ Φ Γ Λ Ω Π Ψ Σ Θ Ξ \f ^ { } \\ [ ~ ] | € Æ æ ß É ! \" # ¤ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? ¡ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z Ä Ö Ñ Ü § ¿ a b c d e f g h i j k l m n o p q r s t u v w x y z ä ö ñ ü à" => 
      "002001200220032004200520062007200820092009200A200B200C200D200E200F2010201120122013201420152016201720182019201A201B0A201B14201B28201B29201B2F201B3C201B3D201B3E201B40201B65201C201D201E201F202120222023202420252026202720282029202A202B202C202D202E202F2030203120322033203420352036203720382039203A203B203C203D203E203F2040204120422043204420452046204720482049204A204B204C204D204E204F2050205120522053205420552056205720582059205A205B205C205D205E205F2060206120622063206420652066206720682069206A206B206C206D206E206F2070207120722073207420752076207720782079207A207B207C207D207E207F"}.each_pair do |k,v|
        assert_equal v, InfobipEncoder::to_gsm7(k)
      end
  end
  # usado applet disponível em http://sms.24cro.com/op_1_4_en.htm
  def test_utf16_encoding
    { 
      "@ £ $ ¥ è é ù ì ò Ç ç Ø ø Å å Δ _ Φ Γ Λ Ω Π Ψ Σ Θ Ξ ^ { } \\ [ ~ ] | € Æ æ ß É ! \" # ¤ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? ¡ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z Ä Ö Ñ Ü § ¿ a b c d e f g h i j k l m n o p q r s t u v w x y z ä ö ñ ü à" => 
      "0040002000A300200024002000A5002000E8002000E9002000F9002000EC002000F2002000C7002000E7002000D8002000F8002000C5002000E5002003940020005F002003A6002003930020039B002003A9002003A0002003A8002003A3002003980020039E0020005E0020007B0020007D0020005C0020005B0020007E0020005D0020007C002020AC002000C6002000E6002000DF002000C9002000210020002200200023002000A400200025002000260020002700200028002000290020002A0020002B0020002C0020002D0020002E0020002F002000300020003100200032002000330020003400200035002000360020003700200038002000390020003A0020003B0020003C0020003D0020003E0020003F002000A10020004100200042002000430020004400200045002000460020004700200048002000490020004A0020004B0020004C0020004D0020004E0020004F002000500020005100200052002000530020005400200055002000560020005700200058002000590020005A002000C4002000D6002000D1002000DC002000A7002000BF0020006100200062002000630020006400200065002000660020006700200068002000690020006A0020006B0020006C0020006D0020006E0020006F002000700020007100200072002000730020007400200075002000760020007700200078002000790020007A002000E4002000F6002000F1002000FC002000E0",
      "Cantem já a canção-ÃO, é assim: ♫ lálálálÁ éh ÉH íh ÍH óh ÓH úh ÚH õw ÕW ♫"=> "00430061006E00740065006D0020006A00E100200061002000630061006E00E700E3006F002D00C3004F002C002000E900200061007300730069006D003A0020266B0020006C00E1006C00E1006C00E1006C00C1002000E90068002000C90048002000ED0068002000CD0048002000F30068002000D30048002000FA0068002000DA0048002000F50077002000D500570020266B",
      "♥ √π÷0=∞ ♥" => "26650020221A03C000F70030003D221E00202665"
    }.each_pair do |k,v|
        assert_equal v, InfobipEncoder::to_utf16(k)
      end
  end
end
