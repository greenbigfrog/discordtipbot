require "mosquito"
require "discordcr"

class NewGuildJob < Mosquito::QueuedJob
  params guild_id : Int64, coin : Int32, owner : Int64

  def perform
  end
end
