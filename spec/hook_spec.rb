# frozen_string_literal: true

require "pry"

class CookHook
  def call(verb); end
end

class PrepareHook
  def call(foo, bar); end
end

class ServeHook
  def call(verb); end
end

class BeforeAllHook
  def call(foo, bar); end
end

class ResourceWithHooks
  include Hook

  before method: :cook, hook: CookHook.new

  after method: :prepare, hook: PrepareHook.new
  after method: :invented_one, hook: PrepareHook.new

  around method: :serve, hook: ServeHook.new

  before hook: BeforeAllHook.new

  def prepare(foo)
    puts "preparing #{foo}"
  end

  def cook
    puts "cooking"
  end

  def serve
    puts "servig food"
  end
end

describe Hook do
  subject { ResourceWithHooks.new }

  it do
    expect_any_instance_of(CookHook).to receive(:call).once
    expect_any_instance_of(BeforeAllHook).to receive(:call).once

    subject.cook
  end

  context "when the method is not defined in the hook" do
    it do
      expect_any_instance_of(CookHook).not_to receive(:call)
      expect_any_instance_of(PrepareHook).to receive(:call)
      expect_any_instance_of(BeforeAllHook).to receive(:call).once

      subject.prepare("bar")
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
      expect_any_instance_of(ServeHook).to receive(:call).once
      # TODO: Review this one
      # expect_any_instance_of(BeforeAllHook).to receive(:call).once
      subject.serve
    end
  end
end
