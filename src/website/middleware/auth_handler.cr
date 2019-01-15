class AuthHandler < Kemal::Handler
  exclude ["/", "/auth/*"] #  "/auth/callback/:platform"]

  def call(env)
    return call_next(env) if exclude_match?(env)

    user_id = env.session.bigint?("user_id")
    unless user_id
      env.session.string("origin", env.request.resource)
      return env.redirect("/auth")
    end

    call_next(env)
  end
end
