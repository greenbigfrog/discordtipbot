require "pg"
require "pg/pg_ext/big_decimal"

require "logger"

require "./website/**"
require "./common/constants"

Website.run
