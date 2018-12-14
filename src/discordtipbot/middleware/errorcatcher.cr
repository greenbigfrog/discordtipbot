class ErrorCatcher
  def call(payload, context)
    yield
  rescue ex
    context[Discord::Client].create_message(payload.channel_id, "There was an unexpected error. This has been reported and should be resolved soon") if payload.is_a?(Discord::Message)
    puts ex.inspect_with_backtrace

    begin
      Raven.capture(Exception.new("Exception while handling message #{payload}", ex))
    rescue
      # Truncate and retry if previous sending failed
      Raven.capture(Exception.new("Exception while handling message #{payload.to_s[0..2000]}"))
    end
  end
end
