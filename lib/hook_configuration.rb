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

  # This determines if this specific hook should be skipped 
  # depending on the method or arguments.
  def skip?(method, *args, **kwargs)
    return true if exclude.include?(method)

    return false if methods.empty?

    !methods.include?(method)
  end
end
