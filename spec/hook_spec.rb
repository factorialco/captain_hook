# frozen_string_literal: true

require 'pry'
require_relative '../lib/hook'

class HookSpy
  def call(verb); end
end

class ResourceWithHooks
  include Hook

  before :cook, HookSpy.new

  # hook :after, :serve, only: :cook, ServeHook.new(some_param: 'foo')

  def prepare
    puts 'preparing'
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

      subject.prepare
    end
  end
end
