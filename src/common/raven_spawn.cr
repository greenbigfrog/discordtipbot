require "raven"

def raven_spawn(*, name : String? = nil, &block)
  wrapped_block = ->{
    begin
      block.call
    rescue ex
      Raven.capture(ex, extra: {
        in_fiber:   true,
        fiber_name: name,
      })
      raise ex
    end
  }
  spawn(name: name, &wrapped_block)
end
