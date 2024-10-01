# frozen_string_literal: true

# Hook configuration parameters these determine how a specific hook will run
class HookConfiguration
  def initialize(hook:, methods: [], inject: [], exclude: [], skip_when: nil)
    @hook = hook
    @methods = methods
    @inject = inject
    @exclude = exclude
    @skip_when = skip_when
  end

  attr_reader :hook, :methods, :inject, :exclude, :skip_when
end
