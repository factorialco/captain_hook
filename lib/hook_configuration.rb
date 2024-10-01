# frozen_string_literal: true

class HookConfiguration
  def initialize(hook:, method: nil, inject: nil, exclude: nil)
    @hook = hook
    @method = method
    @inject = inject || []
    @exclude = exclude || []
  end

  attr_reader :hook, :method, :inject, :exclude
end
