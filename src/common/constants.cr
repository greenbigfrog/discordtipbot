START_TIME = Time.now
TERMS      = "In no event shall this bot or its dev be responsible for any loss, theft or misdirection of funds."
SUPPORT    = "<https://contact.tipbot.info>"
LOG        = Logger.new(STDOUT)
DATA       = PG.connect("postgresql://postgres@database:5432/tipbot")
