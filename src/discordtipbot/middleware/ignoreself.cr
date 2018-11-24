class IgnoreSelf
  def call(payload, ctx)
    yield unless payload.author.id == ctx[Discord::Client].cache.try &.resolve_current_user.id
  end
end
