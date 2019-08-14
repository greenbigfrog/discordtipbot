require "mosquito"
require "pg"
require "pg/pg_ext/big_decimal"
require "discordcr"
require "big"
require "http/client"

require "tb"
require "./jobs/*"

Mosquito::Runner.start
