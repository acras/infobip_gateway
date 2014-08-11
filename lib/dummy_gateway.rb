# encoding: UTF-8

require 'net/http'
require 'uri'
require 'rexml/document'

class DummySender
  attr_accessor :user, :password, :message_text, :sender

  DELIVERYREPORT_URL = "http://localhost:3000/deliveryreport"
  
  def initialize
    @recipients = []
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
  
  # apenas retorna verdadeiro e faz POST em DummySender::DELIVERYREPORT_URL
  # TODO: usar scheduler
  def deliver
    body = get_xml.strip
    Thread.new do
      sleep 5
      # confirma entrega
      url = URI.parse(DELIVERYREPORT_URL)
      req = Net::HTTP::Post.new(url.path)
      req.content_type = 'application/xml'
      req.body = body
      res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        true
      else
        false
        res.error!
      end
    end
    true
  end
  
  def get_xml
    x = <<-EOS
        <DeliveryReport>#{render_recipients.strip}</DeliveryReport>
    EOS
    x.strip
  end

  protected
  def render_recipients
    rec_text = ''
    @recipients.each do |rec|
      rec_text = rec_text + <<-EOS
        <message id="#{rec[:message_id]}" sentdate="#{Time.now}" donedate="#{Time.now}" status="DELIVERED"/>
      EOS
    end
    rec_text
  end
end
