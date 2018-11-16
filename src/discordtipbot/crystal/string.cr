class String
  # Splits given string like required for parsing commands
  def cmd_split
    split(' ', remove_empty: true)
  end
end
