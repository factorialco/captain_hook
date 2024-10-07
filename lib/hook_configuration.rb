# frozen_string_literal: true

# Hook configuration parameters these determine how a specific hook will run
class HookConfiguration
  def initialize(
    hook:,
    methods: [],
    inject: [],
    exclude: [],
    skip_when: nil,
    param_builder: nil
  )
    @hook = hook
    @methods = methods
    @inject = inject
    @exclude = exclude
    @skip_when = skip_when
    @param_builder = param_builder
  end

  attr_reader :hook, :methods, :inject, :exclude, :skip_when, :param_builder
end
