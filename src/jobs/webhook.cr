require "mosquito"
require "http/client"

class WebhookJob < Mosquito::QueuedJob
  params embed : String, webhook_type : String

  def perform
    case webhook_type
    when "admin"   then webhook = ENV["ADMIN_WEBHOOK"]
    when "general" then webhook = ENV["GENERAL_WEBHOOK"]
    else                raise "Invalid webhook type"
    end

    json = "{\"embeds\": [#{embed}]}"
    res = HTTP::Client.post(webhook + "?wait=true", HTTP::Headers{"Content-Type" => "application/json"}, json)
    raise "Error posting to webhook" unless res.success?
  end
end
