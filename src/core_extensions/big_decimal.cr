struct BigDecimal < Number
  def div(other : BigDecimal, max_div_iterations = DEFAULT_MAX_DIV_ITERATIONS) : BigDecimal
    check_division_by_zero other
    other.factor_powers_of_ten

    previous_def(other, max_div_iterations)
  end
end
