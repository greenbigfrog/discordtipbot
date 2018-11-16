class ErrorCatcher
  def call(payload, context)
    yield
  rescue ex
    context[Discord::Client].create_message(payload.channel_id, "There was an unexpected error. This has been reported and should be resolved soon") if payload.is_a?(Discord::Message)
    Raven.capture(Exception.new("Exception while handling message #{payload}", ex))
  end
end
