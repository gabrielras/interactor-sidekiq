# frozen_string_literal: true

require 'interactor'
require 'sidekiq'

module Interactor
  # Internal: Install Interactor's behavior in the given class.
  def self.included(base)
    base.class_eval do
      extend ClassMethods
      extend SidekiqWorker
      include Hooks

      # Public: Gets the Interactor::Context of the Interactor instance.
      attr_reader :context
    end
  end

  # based on Sidekiq 4.x #delay method, which is not enabled by default in Sidekiq 5.x
  # https://github.com/mperham/sidekiq/blob/4.x/lib/sidekiq/extensions/generic_proxy.rb
  # https://github.com/mperham/sidekiq/blob/4.x/lib/sidekiq/extensions/class_methods.rb

  module SidekiqWorker
    class Worker
      include ::Sidekiq::Worker

      def perform(context)
        interactor_class(context).sync_call(context.reject { |c| ['interactor_class'].include? c.to_s })
      rescue Exception => e
        if interactor_class(context).respond_to?(:handle_sidekiq_exception)
          interactor_class(context).handle_sidekiq_exception(e)
        else
          raise e
        end
      end

      private

      def interactor_class(context)
        Module.const_get context[:interactor_class]
      end
    end

    def sync_call(context = {})
      new(context).tap(&:run!).context
    end

    def async_call(context = {})
      options = handle_sidekiq_options(context)
      schedule_options = delay_sidekiq_schedule_options(context)

      Worker.set(options).perform_in(schedule_options.fetch(:delay, 0), handle_context_for_sidekiq(context))
      new(context.to_h).context
    rescue Exception => e
      begin
        new(context.to_h).context.fail!(error: e.message)
      rescue Failure => e
        e.context
      end
    end

    private

    def handle_context_for_sidekiq(context)
      context.to_h.merge(interactor_class: to_s).to_json
    end

    def handle_sidekiq_options(context)
      if context[:sidekiq_options].nil?
        respond_to?(:sidekiq_options) ? sidekiq_options : { queue: :default }
      else
        context[:sidekiq_options]
      end
    end

    def delay_sidekiq_schedule_options(context)
      options = handle_sidekiq_schedule_options(context)
      return {} unless options.key?(:perform_in) || options.key?(:perform_at)

      { delay: options[:perform_in] || options[:perform_at] }
    end

    def handle_sidekiq_schedule_options(context)
      if context[:sidekiq_schedule_options].nil?
        respond_to?(:sidekiq_schedule_options) ? sidekiq_schedule_options : { delay: 0 }
      else
        context[:sidekiq_schedule_options]
      end
    end
  end

  module Async
    def self.included(base)
      base.class_eval do
        include Interactor

        extend ClassMethods
      end
    end

    module ClassMethods
      def call(context = {})
        default_async_call(context)
      end

      def call!(context = {})
        default_async_call(context)
      end

      private

      def default_async_call(context)
        async_call(context)
      end
    end
  end
end
