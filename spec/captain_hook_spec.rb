# frozen_string_literal: true

require "pry"
require "pry-byebug"

class CookHook
  def call(klass, method, policy_context:); end
end

class ManyParametersHook
  def call(_klass, _method, _one, _two, _three, &_block)
    yield
  end
end

class PrepareHook
  def call(klass, method, dto:); end
end

class ServeHook
  def call(_klass, _method, dto: nil)
    yield
  end
end

class BeforeAllHook
  def call(klass, method, dto:); end
end

class CustomError
  def error?
    true
  end
end

class ErroringHook
  def call(_klass, _method)
    CustomError.new
  end
end

class ResourceWithHooks
  include CaptainHook

  hook :before, methods: [:cook], hook: CookHook.new, inject: %i[policy_context unexistent_method]
  hook :before, methods: [:deliver], hook: ErroringHook.new
  hook :before,
       hook: BeforeAllHook.new,
       exclude: [:serve],
       skip_when: ->(_args, kwargs) { !kwargs[:dto] }

  hook :after, methods: %i[prepare invented_one], hook: PrepareHook.new

  hook :around,
       methods: [:prepare],
       hook: ManyParametersHook.new,
       # TODO: Maybe this should be defined in the hook class itself?
       param_builder: lambda { |_instance, _method, args, _kwargs|
         args += [1, 2, 3]

         [args, {}]
       }
  hook :around,
       methods: %i[prepare],
       hook: ServeHook.new

  hook :around,
       methods: %i[serve foo],
       hook: ServeHook.new,
       skip_when: ->(_args, kwargs) { kwargs[:dto] }

  def prepare(dto:)
    puts "preparing #{dto}"

    "preparing #{dto}"
  end

  def cook
    puts "cooking"
  end

  def serve
    "servig food"
  end

  def deliver; end

  def policy_context
    "foo"
  end
end

class ResourceChildWithHooks < ResourceWithHooks
  def foo(dto:); end

  def prepare(dto:)
    super(dto: dto)
    "child #{dto}"
  end
end

describe CaptainHook do
  subject { ResourceWithHooks.new }

  it do
    expect_any_instance_of(CookHook).to receive(:call).with(
      subject,
      :cook, { policy_context: "foo" }
    ).once.and_call_original

    subject.cook
  end

  context "when the method is not defined in the hook" do
    it "calls all hooks with not methods defined" do
      expect_any_instance_of(CookHook).not_to receive(:call).once.and_call_original
      expect_any_instance_of(PrepareHook).to receive(:call).once.and_call_original
      expect_any_instance_of(BeforeAllHook).to receive(:call).once.and_call_original
      expect_any_instance_of(ManyParametersHook).to receive(:call).once.and_call_original
      expect_any_instance_of(ServeHook).to receive(:call).once.and_call_original

      expect(subject.prepare(dto: "bar")).to eq("preparing bar")
    end
  end

  context "when method doesnt exist" do
    it do
      expect { subject.invented_one }.to raise_error(NoMethodError)
      expect_any_instance_of(PrepareHook).not_to receive(:call)
    end
  end

  context "around callback" do
    it do
      expect_any_instance_of(ServeHook).to receive(:call).once.and_call_original
      expect_any_instance_of(BeforeAllHook).to_not receive(:call).and_call_original

      expect(subject.serve).to eq("servig food")
    end
  end

  context "a hook returns an object which responds to #error?" do
    it do
      expect(subject.deliver).to be_a(CustomError)
    end
  end

  context "a subclass of a class with hooks should inherit them" do
    subject { ResourceChildWithHooks.new }

    it do
      expect_any_instance_of(BeforeAllHook).to receive(:call).twice
      subject.foo(dto: "fooing")

      expect_any_instance_of(BeforeAllHook).to receive(:call).once
      expect(subject.prepare(dto: "foo")).to eq("child foo")
    end
  end
end
