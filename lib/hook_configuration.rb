# frozen_string_literal: true

class HookConfiguration
  def initialize(hook:, method:)
    @hook = hook
    @method = method
  end

  attr_reader :hook, :method
end