# frozen_string_literal: true

class HookConfiguration
  def initialize(hook:, methods: [], inject: [], exclude: [])
    @hook = hook
    @methods = methods
    @inject = inject
    @exclude = exclude
  end

  attr_reader :hook, :methods, :inject, :exclude
end
