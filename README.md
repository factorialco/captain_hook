# captain_hook

A ruby gem to decorate your methods and run arbitrary hooks `before`, `after`
or `around` them. It is similar on how Rails does with `before_action`,
`after_action` and `around_action` but this for any class.

It automatically wraps the configured methods to call the hooks `before`,
`after` or `around` them.

## Installation

Add the following line to your Gemfile:

```ruby
gem 'captain_hook', git: 'https://github.com/factorialco/captain_hook.git', branch: 'main'
```

Then `bundle install`

## Using it

In order to inject the hook behavior, you need to include the `CaptainHook`
module in your class and use the `hook` method to decorate the methods you want
to hook.

### Registering the hooks

```ruby
class MyService
  include CaptainHook

  hook :before, methods: [:cook], hook: CookHook.new, inject: [:policy_context]
  hook :before, methods: [:deliver], hook: ErroringHook.new
  hook :before,
       hook: BeforeAllHook.new,
       exclude: [:serve],
       skip_when: ->(_args, kwargs) { !kwargs[:dto] }

  hook :after, methods: [:prepare], hook: PrepareHook.new
  hook :after, methods: [:invented_one], hook: PrepareHook.new

  hook :around,
       methods: %i[serve foo],
       hook: ServeHook.new,
       skip_when: ->(_args, kwargs) { kwargs[:dto] }

  def prepare(dto:); end

  def cook; end

  def serve; end

  def deliver; end
end
```

Parameters:

- `methods`: an array of method names to hook. If not specified, it will hook
  all methods.
- `hook`: the instance of the hook to run.
- inject: The hook will receive these additional keyword arguments from the
  class hosting the method.
- `exclude`: an array of method names to exclude from being hooked.
- skip_when: a lambda that receives the positional and keyword arguments of the
  method being decorated and returns a boolean to skip the hook.

### Implementing your hooks

You need to implement a class with the `#call` method.
This method will receive the following positional parameters:

- klass: the class where the method is defined
- method: the method name
- block: the original method (useful for around hooks)

Additionally it will receive the positional and keyword arguments of the
original method being decorated.

You can inject additional keyword parameters by using the `inject` parameter
when registering the hook.

### Caveats

- You can not call super from a child class decorated method, you will enter in
an infinite loop
