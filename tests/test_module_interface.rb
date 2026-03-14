class TestModuleInterface < VmaTest
  # Ensure the calculator is inactive before each test that needs a clean slate.
  def ensure_disabled
    if vma.actions.include?(:insert_calculator)
      calculator_disable if respond_to?(:calculator_disable, true)
    end
  end

  def load_calculator
    load ppath("modules/calculator/calculator.rb")
  end

  # --- _info ---

  def test_info_structure
    load ppath("modules/calculator/calculator_info.rb")
    info = calculator_info
    assert info[:name].is_a?(String),  "name should be a String"
    assert !info[:name].empty?,        "name should not be empty"
    assert info.key?(:no_restart),     "no_restart key missing"
    assert_eq true, info[:no_restart], "calculator should be no_restart"
  end

  # --- _init ---

  def test_init_registers_action
    ensure_disabled
    load_calculator
    calculator_init
    assert vma.actions.include?(:insert_calculator), "action not registered after init"
  ensure
    calculator_disable
  end

  def test_init_adds_menu_item
    ensure_disabled
    load_calculator
    calculator_init
    assert vma.gui.menu.module_action?(:insert_calculator), "menu item missing after init"
  ensure
    calculator_disable
  end

  # --- _disable ---

  def test_disable_unregisters_action
    ensure_disabled
    load_calculator
    calculator_init
    calculator_disable
    assert !vma.actions.include?(:insert_calculator), "action still registered after disable"
  end

  def test_disable_removes_menu_item
    ensure_disabled
    load_calculator
    calculator_init
    calculator_disable
    assert !vma.gui.menu.module_action?(:insert_calculator), "menu item still present after disable"
  end

  # --- cycle ---

  def test_init_disable_cycle
    ensure_disabled
    load_calculator
    3.times do |i|
      calculator_init
      assert vma.actions.include?(:insert_calculator),        "action missing after init (cycle #{i})"
      assert vma.gui.menu.module_action?(:insert_calculator), "menu missing after init (cycle #{i})"
      calculator_disable
      assert !vma.actions.include?(:insert_calculator),        "action present after disable (cycle #{i})"
      assert !vma.gui.menu.module_action?(:insert_calculator), "menu present after disable (cycle #{i})"
    end
  end

  # --- all_settings_defs ---

  def test_settings_defs_has_modules_section
    defs = all_settings_defs
    assert defs.any? { |s| s[:label] == "Modules" }, "no Modules section"
  end

  def test_settings_defs_calculator_key_present
    defs = all_settings_defs
    mod = defs.find { |s| s[:label] == "Modules" }
    assert !mod.nil?, "no Modules section"
    calc = mod[:settings].find { |s| s[:key] == [:modules, :calculator, :enabled] }
    assert !calc.nil?, "calculator key missing from Modules section"
  end

  def test_settings_defs_no_restart_flag
    defs = all_settings_defs
    mod  = defs.find { |s| s[:label] == "Modules" }
    calc = mod[:settings].find { |s| s[:key] == [:modules, :calculator, :enabled] }
    assert_eq true, calc[:no_restart], "calculator should have no_restart: true"
  end
end
