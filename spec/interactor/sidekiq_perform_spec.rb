# frozen_string_literal: true

require 'interactor/sidekiq'

RSpec.describe Interactor::SidekiqWorker::Worker do
  class AsyncAction
    include Interactor::Async

    def call
      { message: context.variable }
    end
  end

  class BadAsyncAction
    include Interactor::Async

    def call
      raise StandardError, 'This is an exception'
    end
  end

  class CustomizedBadAsyncAction
    include Interactor::Async

    def call
      raise StandardError, 'This is an exception'
    end

    def self.handle_sidekiq_exception(error)
      { message: error.respond_to?(:message) ? 'captured error message' : 'not captured error message' }
    end
  end

  shared_examples_for 'there was no new sidekiq worker' do
    let(:jobs_by_queue) { Sidekiq::Queues.jobs_by_queue }

    before { Sidekiq::Queues.clear_all }
    before { result }

    it { expect(respond_to?(:jobs_by_queue)).to be_truthy }
  end

  describe '#perform' do
    let(:sidekiq_options) { { queue: 'default' } }

    context 'when there is no error' do
      subject(:result) { AsyncAction::SidekiqWorker::Worker.new.perform(context) }
      let(:context) { { interactor_class: 'AsyncAction', key: 'value' } }

      it { expect(result.class).to eq Interactor::Context }

      it { expect(result.success?).to eq true }

      it { expect(result.to_h).to eq context.except(:interactor_class) }

      it_behaves_like 'there was no new sidekiq worker'
    end

    context 'when there is no error and it is handled' do
      subject(:result) { CustomizedBadAsyncAction::SidekiqWorker::Worker.new.perform(context) }
      let(:context) { { interactor_class: 'CustomizedBadAsyncAction', key: 'value' } }

      it { expect(result).to eq({ message: 'captured error message' }) }

      it_behaves_like 'there was no new sidekiq worker'
    end

    context 'when there is no error and it is not handled' do
      subject(:result) { BadAsyncAction::SidekiqWorker::Worker.new.perform(context) }
      let(:context) { { interactor_class: 'BadAsyncAction', key: 'value' } }

      it 'returns error' do
        expect { result }.to raise_error(StandardError, 'This is an exception')
      end
    end
  end
end
