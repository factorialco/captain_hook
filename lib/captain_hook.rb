# frozen_string_literal: true

require_relative "./hook_configuration"

# Strong inspiration on https://github.com/collectiveidea/interactor/blob/master/lib/interactor/hooks.rb
#
# Hook module, responsible to add the before, after and around callbacks on the
# public methods of the class which requires it.
module CaptainHook
  # Install Hook methods in the including class.
  def self.included(base)
    base.class_eval do
      extend ClassMethods

      def self.inherited(subclass)
        super
        subclass.class_eval do
          extend ClassMethods
        end
      end
    end
  end

  # Around hooks are a bit different from before and after hooks, as they
  # need to be executed in a stack-like way.
  def run_around_hooks(method, *args, **kwargs, &block)
    self.class.get_hooks(:around).to_a.reverse.inject(block) do |chain, hook_configuration|
      next chain if hook_configuration.skip?(method, args, kwargs)

      instance = self

      hook_proc = proc {
        run_hook(method, hook_configuration, chain, instance, *args, **kwargs)
      }

      next hook_proc if hook_configuration.methods.empty?

      next chain if hook_configuration.skip?(method, args, kwargs)

      hook_proc
    end.call
  end

  # Runs non-around hooks for a given method.
  def run_hooks(method, hooks, *args, **kwargs)
    hooks.each do |hook_configuration|
      next if hook_configuration.skip?(method, *args, **kwargs)

      body = run_hook(method, hook_configuration, -> {}, self, *args, **kwargs)

      return body if hook_error?(body)
    end
  end

  # Runs an specific hook based on its configuration
  def run_hook(method, hook_configuration, chain, instance, *args, **kwargs)
    if hook_configuration.inject
      kwargs = kwargs.merge(hook_configuration.inject.each_with_object({}) do |inject, hash|
        # If the method does not respond to the inject method, we skip it
        next unless instance.respond_to?(inject)

        hash[inject] = instance.send(inject)
      end)
    end

    args, kwargs = hook_configuration.param_builder.call(self, method, args, kwargs) if hook_configuration.param_builder

    hook_configuration.hook.call(self, method, *args, **kwargs, &chain)
  rescue ArgumentError => e
    puts "Argument error running hook: #{hook_configuration.hook.class.name} with method: #{method}, args: #{args}, kwargs: #{kwargs}"

    raise e
  end

  def hook_error?(result)
    result.respond_to?(:error?) && result.error?
  end

  # Class methods for the including class.
  module ClassMethods
    ####
    # Hooks logic part
    ####
    # Get all hooks from ancestors so you can define hooks in a parent class
    def get_ancestor_hooks
      ancestor_hooks = { before: {}, after: {}, around: {} }

      ancestors.each do |ancestor|
        next unless ancestor.respond_to?(:hooks)

        ancestor.hooks[:before].each_value do |hook|
          ancestor_hooks[:before][hook.hook.class.name] = hook
        end

        ancestor.hooks[:after].each_value do |hook|
          ancestor_hooks[:after][hook.hook.class.name] = hook
        end

        ancestor.hooks[:around].each_value do |hook|
          ancestor_hooks[:around][hook.hook.class.name] = hook
        end
      end

      ancestor_hooks
    end

    def get_hooks(kind)
      all_hooks = (get_ancestor_hooks[kind].values + hooks[kind].values).uniq(&:hook)
      all_hooks.flatten
    end

    def hooks
      @hooks ||= { before: {}, after: {}, around: {} }
    end

    # Main hook configuartion entrypoint
    # Examples:
    # hook :before, hook: CookHook.new, methods: [:cook], inject: [:policy_context]
    # hook :before, hook: ErroringHook.new
    # hook :around, hook: ServeHook.new
    def hook(
      kind,
      hook:,
      methods: [],
      inject: [],
      exclude: [],
      skip_when: nil,
      param_builder: nil
    )
      hooks[kind][hook] = HookConfiguration.new(
        hook: hook,
        methods: methods,
        inject: inject,
        exclude: exclude,
        skip_when: skip_when,
        param_builder: param_builder
      )
    end

    ####
    # Decorator pattern logic part
    ####
    def overriden?(method)
      overriden_methods.include? method
    end

    def method_added(method_name)
      if !public_method_defined?(method_name) || overriden?(method_name) ||
         method_name.to_s.end_with?("__without_hooks")
        return super(method_name)
      end

      decorate_method!(method_name)
    ensure
      super(method_name)
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

      alias_method original_method_name, method_name

      # We decorate the method with the before, after and around hooks
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
end
