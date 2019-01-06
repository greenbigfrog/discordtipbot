class ErrorCatcher
  def call(payload, context)
    yield
  rescue ex
    if payload.is_a?(Discord::Message)
      unless ex.is_a?(DB::PoolRetryAttemptsExceeded)
        context[Discord::Client].create_message(payload.channel_id, "There was an unexpected error. This has been reported and should be resolved soon")
      end
    end
    puts ex.inspect_with_backtrace

    # Truncate all payloads for now
    Raven.capture(Exception.new("Exception while handling message #{payload.to_s[0..2000]}"))
  end
end
