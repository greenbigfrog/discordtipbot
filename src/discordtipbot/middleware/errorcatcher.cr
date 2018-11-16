class ErrorCatcher
  def call(payload, context)
    yield
  rescue ex
    Raven.capture(Exception.new("Exception while handling message #{payload}", ex))
  end
end
