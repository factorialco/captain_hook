# frozen_string_literal: true

require "pry"
require "pry-byebug"

class DummyHook
  def call(klass, method, dto:); end
end

describe CaptainHook::Configuration do
  let(:hook) { DummyHook.new }
  let(:args) { {} }
  let(:kwargs) { {} }
  let(:method) { :foo }
  let(:excluded_method) { :excluded_foo }
  let(:include) { [method] }
  let(:skip_when) { nil }

  subject do
    described_class.new(
      hook: hook,
      include: include,
      exclude: [excluded_method],
      skip_when: skip_when
    )
  end

  describe "#skip?" do
    context "when the method is included" do
      it do
        expect(subject.skip?(method, args, kwargs)).to be_falsey
      end
    end

    context "when include is empty should always run" do
      let(:include) { [] }

      it do
        expect(subject.skip?(method, args, kwargs)).to be_falsey
      end
    end

    context "when the method is excluded" do
      it do
        expect(subject.skip?(excluded_method, args, kwargs)).to be_truthy
      end
    end

    context "when skip_when block is provided" do
      let(:skip_when) { ->(_args, kwargs) { kwargs[:dto].nil? } }

      it "it evaluates the skip_when to decide if its shown" do
        expect(subject.skip?(method, args, kwargs)).to be_truthy
      end
    end
  end
end
