# frozen_string_literal: true

require 'interactor/sidekiq'

RSpec.describe Interactor::SidekiqWorker do
  class RegularAction
    include Interactor

    def call
      { context: context.variable }
    end
  end

  class AsyncAction
    include Interactor::Async

    def call
      { context: context.variable }
    end

    def self.handle_sidekiq_exception(error); end
  end

  class AsyncActionWithSidekiqOption
    include Interactor::Async

    def call
      { context: context.variable }
    end

    def self.sidekiq_options
      { queue: 'low_priority' }
    end
  end

  class AsyncActionWithSidekiqScheduleOption
    include Interactor::Async

    def call
      { context: context.variable }
    end

    def self.sidekiq_schedule_options
      { perform_in: 5 }
    end
  end

  class CustomizedBadSidekiqOption
    include Interactor::Async

    def call
      { context: context.variable }
    end

    def self.sidekiq_options
      'bad error message'
    end
  end

  class CustomizedBadSidekiqScheduleOption
    include Interactor::Async

    def call
      { context: context.variable }
    end

    def self.sidekiq_schedule_options
      'bad error message'
    end
  end

  class RegularOrganizer
    include Interactor::Organizer

    organize RegularAction
  end

  class OrganizerWithAsyncAction
    include Interactor::Organizer

    organize RegularAction, AsyncActionWithSidekiqOption, AsyncActionWithSidekiqScheduleOption
  end

  shared_examples_for 'sidekiq worker' do |elements|
    let(:jobs_by_queue) { Sidekiq::Queues.jobs_by_queue[(elements[:sidekiq_options][:queue])][0] }

    before { Sidekiq::Queues.clear_all }
    before { result }

    it { expect(jobs_by_queue['queue']).to eq elements[:sidekiq_options][:queue] }

    it { expect(jobs_by_queue['args']).to eq [context.merge(interactor_class: elements[:interactor_class]).to_json] }
  end

  shared_examples_for 'there is no sidekiq worker' do
    let(:jobs_by_queue) { Sidekiq::Queues.jobs_by_queue }

    before { Sidekiq::Queues.clear_all }
    before { result }

    
    it { expect(respond_to?(:jobs_by_queue)).to be_truthy }
  end

  shared_examples_for 'interactor success' do
    it { expect(result.class).to eq Interactor::Context }

    it { expect(result.success?).to eq true }

    it { expect(result.to_h).to eq context }
  end

  shared_examples_for 'interactor failure' do
    it { expect(result.class).to eq Interactor::Context }

    it { expect(result.failure?).to eq true }

    it { expect(result.error).not_to be_empty }
  end

  describe '#async_call' do
    subject(:result) { interactor.async_call(context) }

    %w[RegularAction AsyncAction RegularOrganizer OrganizerWithAsyncAction].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid and not in context' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class,  sidekiq_options: { queue: 'default' },
                                            sidekiq_schedule_options: { delay: 0 }

          it_behaves_like 'interactor success'
        end

        context 'when attributes are valid and in context' do
          let(:context) do
            { key: 'value', sidekiq_options: { queue: 'low_priority' }, sidekiq_schedule_options: { perform_in: 5 } }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class, sidekiq_options: { queue: 'low_priority' },
                                            sidekiq_schedule_options: { perform_in: 5 }

          it_behaves_like 'interactor success'
        end

        context 'when attributes are invalid' do
          let(:context) do
            { key: 'value', sidekiq_options: 'bad error message',
              sidekiq_schedule_options: 'bad error message' }
          end

          it_behaves_like 'there is no sidekiq worker'

          it_behaves_like 'interactor failure'
        end
      end
    end

    %w[AsyncActionWithSidekiqOption].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid and not in context' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class,  sidekiq_options: { queue: 'low_priority' },
                                            sidekiq_schedule_options: { delay: 0 }

          it_behaves_like 'interactor success'
        end

        context 'when attributes are valid and in context' do
          let(:context) do
            { key: 'value', sidekiq_options: { queue: 'default' }, sidekiq_schedule_options: { perform_in: 5 } }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class, sidekiq_options: { queue: 'default' },
                                            sidekiq_schedule_options: { perform_in: 5 }

          it_behaves_like 'interactor success'
        end

        context 'when attributes are invalid' do
          let(:context) do
            { key: 'value', sidekiq_options: 'bad error message' }
          end

          it_behaves_like 'there is no sidekiq worker'

          it_behaves_like 'interactor failure'
        end
      end
    end

    %w[AsyncActionWithSidekiqScheduleOption].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid and not in context' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class, sidekiq_options: { queue: 'default' },
                                            sidekiq_schedule_options: { perform_in: 5 }

          it_behaves_like 'interactor success'
        end

        context 'when attributes are valid and in context' do
          let(:context) do
            { key: 'value', sidekiq_options: { queue: 'low_priority' }, sidekiq_schedule_options: { perform_in: 0 } }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class, sidekiq_options: { queue: 'low_priority' },
                                            sidekiq_schedule_options: { perform_in: 0 }

          it_behaves_like 'interactor success'
        end

        context "when attributes for #{interactor_class} class are invalid" do
          let(:context) do
            { key: 'value', sidekiq_schedule_options: 'bad error message' }
          end

          it_behaves_like 'there is no sidekiq worker'

          it_behaves_like 'interactor failure'
        end
      end
    end

    %w[CustomizedBadSidekiqOption CustomizedBadSidekiqScheduleOption].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid' do
          let(:context) do
            { key: 'value', sidekiq_options: { queue: 'default' }, sidekiq_schedule_options: { delay: 5 } }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class,  sidekiq_options: { queue: 'default' },
                                            sidekiq_schedule_options: { delay: 5 }

          it_behaves_like 'interactor success'
        end

        context 'when attributes are invalid' do
          let(:context) { { key: 'value' } }

          it_behaves_like 'there is no sidekiq worker'

          it_behaves_like 'interactor failure'
        end
      end
    end
  end

  describe '#call' do
    subject(:result) { interactor.call(context) }

    %w[RegularAction RegularOrganizer].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid and not in context' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'there is no sidekiq worker'

          it_behaves_like 'interactor success'
        end

        context 'when attributes are valid and in context' do
          let(:context) do
            { key: 'value', sidekiq_options: { queue: 'low_priority' }, sidekiq_schedule_options: { perform_in: 5 } }
          end

          it_behaves_like 'there is no sidekiq worker'

          it_behaves_like 'interactor success'
        end
      end
    end

    %w[AsyncAction].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class,  sidekiq_options: { queue: 'default' },
                                            sidekiq_schedule_options: { delay: 0 }

          it_behaves_like 'interactor success'
        end
      end
    end

    %w[OrganizerWithAsyncAction].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'sidekiq worker', interactor_class: 'AsyncActionWithSidekiqScheduleOption',
                                            sidekiq_options: { queue: 'default' },
                                            sidekiq_schedule_options: { delay: 0 }

          it_behaves_like 'interactor success'
        end
      end
    end

    %w[AsyncActionWithSidekiqOption].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class,  sidekiq_options: { queue: 'low_priority' },
                                            sidekiq_schedule_options: { delay: 0 }

          it_behaves_like 'interactor success'
        end
      end
    end

    %w[AsyncActionWithSidekiqScheduleOption].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'sidekiq worker', interactor_class: interactor_class, sidekiq_options: { queue: 'default' },
                                            sidekiq_schedule_options: { perform_in: 5 }

          it_behaves_like 'interactor success'
        end
      end
    end

    %w[CustomizedBadSidekiqOption CustomizedBadSidekiqScheduleOption].each do |interactor_class|
      context "when attributes for #{interactor_class} class" do
        let(:interactor) { Module.const_get interactor_class }

        context 'when attributes are valid' do
          let(:context) do
            { key: 'value' }
          end

          it_behaves_like 'there is no sidekiq worker'

          it_behaves_like 'interactor failure'
        end
      end
    end
  end
end
