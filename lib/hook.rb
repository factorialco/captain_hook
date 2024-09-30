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
      next proc { run_hook(hook_configuration, chain, *args, **kwargs) } if hook_configuration.method.nil?

      next chain unless hook_configuration.method == method

      proc { run_hook(hook_configuration, chain, args, kwargs) }
    end.call
  end

  def run_before_hooks(method, *args, **kwargs)
    run_hooks(method, self.class.get_hooks(:before), *args, **kwargs)
  end

  def run_after_hooks(method, *args, **kwargs)
    run_hooks(method, self.class.get_hooks(:after), *args, **kwargs)
  end

  def run_hooks(method, hooks, *args, **kwargs)
    hooks.each do |hook_configuration|
      body = run_hook(hook_configuration, [], *args, **kwargs) if hook_configuration.method.nil?

      return body if hook_error?(body)
      next unless hook_configuration.method == method

      body = run_hook(hook_configuration, [], *args, **kwargs)

      return body if hook_error?(body)
    end
  end

  def run_hook(hook_configuration, chain, *args, **kwargs)
    hook_configuration.hook.call(chain, *args, **kwargs)
  end

  def hook_error?(result)
    result.respond_to?(:error?) && result.error?
  end

  # Class methods for the including class.
  module ClassMethods
    ####
    # Hooks logic part
    ####
    def before_hooks
      # self.class.ancestors.map { |a| a.respond_to?(:before_hooks) ? a.before_hooks : [] }
      @before_hooks ||= []
    end

    def hooks
      { before: before_hooks.to_set, after: after_hooks.to_set, around: around_hooks.to_set }
    end

    def get_ancestor_hooks
      ancestor_hooks = { before: {}, after: {}, around: {} }

      ancestors.each do |ancestor|
        next unless ancestor.respond_to?(:get_hooks)

        ancestor.before_hooks.each do |hook|
          ancestor_hooks[:before][hook.hook.class.name] = hook
        end

        ancestor.after_hooks.each do |hook|
          ancestor_hooks[:after][hook.hook.class.name] = hook
        end

        ancestor.around_hooks.each do |hook|
          ancestor_hooks[:around][hook.hook.class.name] = hook
        end
      end

      ancestor_hooks
    end

    def get_hooks(kind)
      (hooks[kind] + get_ancestor_hooks[kind].values).flatten
    end

    def after_hooks
      @after_hooks ||= []
    end

    def around_hooks
      @around_hooks ||= []
    end

    def before(hook:, method: nil)
      before_hooks.push(HookConfiguration.new(hook: hook, method: method))
    end

    def after(hook:, method: nil)
      after_hooks.push(HookConfiguration.new(hook: hook, method: method))
    end

    def around(hook:, method: nil)
      around_hooks.push(HookConfiguration.new(hook: hook, method: method))
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
        run_around_hooks(method_name, *args, **kwargs) do
          before_hook_result = run_before_hooks(method_name, *args, **kwargs)

          return before_hook_result if hook_error?(before_hook_result)

          # Supporting any kind of method, without arguments, with positional
          # or with named parameters. Or any combination of them.
          result = if kwargs.any? && args.any?
                     send(original_method_name, *args, **kwargs)
                   elsif kwargs.any?
                     send(original_method_name, **kwargs)
                   elsif args.any?
                     send(original_method_name, *args)
                   else
                     send(original_method_name)
                   end

          run_after_hooks(method_name, *args, **kwargs)

          result
        end
      end
    end
  end
end
