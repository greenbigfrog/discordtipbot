require "./spec_helper"

class UtilityBot
  include Utilities
end

describe Utilities do
  bot = UtilityBot.new

  describe "#split" do
    context "with a message 2000 characters or less" do
      it "doesn't split" do
        message = "a" * 2000
        bot.split(message).should eq [message]
      end
    end

    context "with a message over 2000 characters" do
      it "splits into multiple messages" do
        messages = [
          "a" * 2000,
          "b" * 2000,
          "c" * 2000,
        ]
        message = messages.join
        bot.split(message).should eq messages
      end
    end
  end

  describe "#build_user_string" do
    context "mention is false" do
      pending "builds a string of usernames" do
      end
    end

    context "mention is true" do
      pending "builds a string of mentions" do
      end
    end
  end
end
