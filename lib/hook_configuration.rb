# frozen_string_literal: true

class HookConfiguration
  def initialize(hook:, method: nil, inject: nil)
    @hook = hook
    @method = method
    @inject = inject
  end

  attr_reader :hook, :method, :inject
end
