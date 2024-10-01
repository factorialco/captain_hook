# frozen_string_literal: true

require_relative "./hook_configuration"

# Strong inspiration on https://github.com/collectiveidea/interactor/blob/master/lib/interactor/hooks.rb
#
# Hook module, responsible to add the before, after and around callbacks on the
# public methods of the class which requires it.
module Hook
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
  # need to be executed in a stack-like way. This method is responsible to
  #
  # 1. Reverse the order of the around hooks, so they are executed
  #   in the right order.
  #
  def run_around_hooks(method, *args, **kwargs, &block)
    self.class.get_hooks(:around).to_a.reverse.inject(block) do |chain, hook_configuration|
      hook_proc = proc { run_hook(method, hook_configuration, chain, *args, **kwargs) }
      next hook_proc if hook_configuration.method.nil?

      next chain unless hook_configuration.method == method

      hook_proc
    end.call
  end

  def run_hooks(method, hooks, *args, **kwargs)
    hooks.each do |hook_configuration|
      next if hook_configuration.exclude.include?(method)

      body = run_hook(method, hook_configuration, -> {}, *args, **kwargs) if hook_configuration.method.nil?

      return body if hook_error?(body)
      next unless hook_configuration.method == method

      body = run_hook(method, hook_configuration, -> {}, *args, **kwargs)

      return body if hook_error?(body)
    end
  end

  def run_hook(method, hook_configuration, chain, *args, **kwargs)
    if hook_configuration.inject
      kwargs = kwargs.merge(hook_configuration.inject.each_with_object({}) do |inject, hash|
        hash[inject] = send(inject)
      end)
    end

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

    def hook(kind, hook:, method: nil, inject: nil, exclude: nil)
      hooks[kind][hook] = HookConfiguration.new(hook: hook, method: method, inject: inject, exclude: exclude)
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
        around_body = lambda do |*_args, **_kwargs|
          # Run before hooks
          before_hook_result = run_hooks(method_name, self.class.get_hooks(:before), *args, **kwargs)

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
          run_hooks(method_name, self.class.get_hooks(:after), *args, **kwargs)

          result
        end

        result = run_around_hooks(method_name, *args, **kwargs, &around_body)
        result
      end
    end
  end
end
