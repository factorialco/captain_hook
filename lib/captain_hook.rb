# frozen_string_literal: true

require_relative "./captain_hook/configuration"

# Strong inspiration on https://github.com/collectiveidea/interactor/blob/master/lib/interactor/hooks.rb
#
# Hook module, responsible to add the before, after and around callbacks on the
# public methods of the class which requires it.
module CaptainHook
  # Install Hook methods in the including class.
  def self.included(base)
    base.class_eval do
      extend ClassMethods
    end
  end

  # Class methods for the including class.
  module ClassMethods
    # Main hook configuartion entrypoint, DSL
    # Examples:
    # hook :before, hook: CookHook.new, include: [:cook], inject: [:policy_context]
    # hook :before, hook: ErroringHook.new
    # hook :around, hook: ServeHook.new
    def hook(
      kind,
      hook:,
      include: [],
      inject: [],
      exclude: [],
      skip_when: nil,
      param_builder: nil
    )
      hooks[kind][hook] = Configuration.new(
        hook: hook,
        include: include,
        inject: inject,
        exclude: exclude,
        skip_when: skip_when,
        param_builder: param_builder
      )
    end

    ####
    # Hooks logic part
    ####
    def get_hooks(kind)
      ancestors.each_with_object({}) do |klass, hook_list|
        next unless klass.respond_to?(:hooks)

        klass.hooks[kind]&.each_value do |hook|
          hook_list[hook.hook.class] ||= hook
        end
      end.values
    end

    def hooks
      @hooks ||= { before: {}, after: {}, around: {} }
    end

    ####
    # Decorator pattern logic part
    ####
    def overriden?(method)
      overriden_methods.include? method
    end

    def method_excluded_by_all_hooks?(method)
      get_hooks(:before).all? { |hook| hook.exclude.include?(method) } &&
        get_hooks(:after).all? { |hook| hook.exclude.include?(method) } &&
        get_hooks(:around).all? { |hook| hook.exclude.include?(method) }
    end

    def method_added(method_name)
      unless !public_method_defined?(method_name) || overriden?(method_name) ||
             method_name.to_s.end_with?("__without_hooks")

        decorate_method!(method_name)
      end

      super
    end

    def overriden_methods
      @overriden_methods ||= Set.new
    end

    def mark_as_overriden!(method)
      overriden_methods << method
    end

    # Replaces the method with a decorated version of it
    def decorate_method!(method_name)
      mark_as_overriden!(method_name)

      original_method_name = :"#{method_name}__without_hooks"

      # Skip if the method is excluded by all hooks
      return if method_excluded_by_all_hooks?(method_name)

      alias_method original_method_name, method_name

      define_method(method_name) do |*args, **kwargs|
        hook_args = args
        hook_kwargs = kwargs

        around_body = lambda do
          # Run before hooks
          before_hook_result = run_hooks(method_name, self.class.get_hooks(:before), *hook_args, **hook_kwargs)

          return before_hook_result if hook_error?(before_hook_result)

          # Supporting any kind of method, without arguments, with positional
          # or with named parameters. Or any combination of them.
          result = if args.empty? && kwargs.empty?
                     send(original_method_name)
                   elsif args.empty?
                     send(original_method_name, **kwargs)
                   elsif kwargs.empty?
                     if args.length == 1 && args[0].is_a?(Hash)
                       send(original_method_name, **args[0])
                     else
                       send(original_method_name, *args)
                     end
                   else
                     send(original_method_name, *args, **kwargs)
                   end

          # Run after hooks
          run_hooks(method_name, self.class.get_hooks(:after), *hook_args, **hook_kwargs)

          result
        end

        result = run_around_hooks(method_name, *hook_args, **hook_kwargs, &around_body)

        result
      end
    end
  end

  def prepare_hook_params(method, hook_configuration, args, kwargs)
    return hook_configuration.param_builder.call(self, method, args, kwargs) if hook_configuration.param_builder

    [args, kwargs]
  end

  # Around hooks are a bit different from before and after hooks, as they
  # need to be executed in a stack-like way.
  def run_around_hooks(method, *args, **kwargs, &block)
    self.class.get_hooks(:around).to_a.reverse.inject(block) do |chain, hook_configuration|
      hook_args, hook_kwargs = prepare_hook_params(method, hook_configuration, args, kwargs)
      next chain if hook_configuration.skip?(method, *hook_args, **hook_kwargs)

      proc {
        run_hook(method, hook_configuration, chain, *hook_args, **hook_kwargs)
      }
    end.call
  end

  # Runs non-around hooks for a given method.
  def run_hooks(method, hooks, *args, **kwargs)
    hooks.each do |hook_configuration|
      hook_args, hook_kwargs = prepare_hook_params(method, hook_configuration, args, kwargs)
      next if hook_configuration.skip?(method, *hook_args, **hook_kwargs)

      body = run_hook(method, hook_configuration, -> {}, *hook_args, **hook_kwargs)
      return body if hook_error?(body)
    end
  end

  # Runs an specific hook based on its configuration
  def run_hook(method, hook_configuration, chain, *args, **kwargs)
    # puts "Running hook: #{hook_configuration.hook.class.name} with method: #{self.class.name}##{method}"
    hook_configuration.hook.call(self, method, *args, **kwargs, &chain)
  rescue ArgumentError => e
    puts "Argument error running hook: #{hook_configuration.hook.class.name} with method: #{method}, args: #{args}, kwargs: #{kwargs}"
    raise e
  end

  def hook_error?(result)
    result.respond_to?(:error?) && result.error?
  end
end
