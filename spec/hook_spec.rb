# frozen_string_literal: true

require 'pry'
require_relative '../lib/hook'

class HookSpy
  def call(verb); end
end

class HookSpy2
  def call(foo, bar); end
end

class ResourceWithHooks
  include Hook

  before :cook, HookSpy.new

  after :prepare, HookSpy2.new

  def prepare(foo)
    puts "preparing #{foo}"
  end

  def cook
    puts 'cooking'
  end
end

describe Hook do
  subject { ResourceWithHooks.new }

  it do
    expect_any_instance_of(HookSpy).to receive(:call).once

    subject.cook
  end

  context 'when the method is not defined in the hook' do
    it do
      expect_any_instance_of(HookSpy).not_to receive(:call)

      subject.prepare('bar')
    end
  end
end
