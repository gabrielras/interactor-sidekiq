# Interactor::Sidekiq

Provides [Interactor](https://github.com/collectiveidea/interactor) with asynchronous action using [Sidekiq](https://github.com/mperham/sidekiq).

## Installation

```ruby
gem 'interactor-sidekiq', '~> 1.0'
```

## #async_call
You can now add asynchronous behavior to both types of inetagents (basic interactors and organizers).

```ruby
class RegularAction
  include Interactor

  def call
    { context: context.variable }
  end
end
```
With the above example we can already use **async_call**.

```sh
>> RegularAction.call(key: 'value')
#<Interactor::Context key="value">
>> Sidekiq::Queues.jobs_by_queue
{}
```
```sh
>> RegularAction.async_call(key: 'value')
#<Interactor::Context key="value">
>> Sidekiq::Queues.jobs_by_queue
{"default"=>[{"retry"=>true, "queue"=>"default", "args"=>["{\"key\":\"value\",\"interactor_class\":\"RegularAction\"}"], "class"=>"Interactor::SidekiqWorker::Worker", "jid"=>"91a374e10e584b02cb84eec3", "created_at"=>1656283783.3459146, "enqueued_at"=>1656283783.3459556}]}
```

You can pass the **sidekiq_options** and **sidekiq_scheduling_options** to customize the behavior of the **async_call** method.

#### Passing options from sidekiq

To set custom [sidekiq_options] (https://github.com/mperham/sidekiq/wiki/Advanced-Options#workers) you can add `sidekiq_options` class method in your interactors - these options will be passed to Sidekiq `` set ` before scheduling the asynchronous worker.

#### Passing scheduling options

In order to be able to schedule jobs for future execution following [Scheduled Jobs](https://github.com/mperham/sidekiq/wiki/Scheduled-Jobs), you can add the `sidekiq_schedule_options` class method in your subscriber definition - these options will be passed to Sidekiq's `perform_in` method when the worker is called.

```sh
>> RegularAction.async_call(message: 'hello!', sidekiq_options: { queue: :low_priority }, sidekiq_schedule_options: { perform_in: 5 })

Interactor::Context message: 'hello!', sidekiq_options: { queue: :low_priority }, sidekiq_schedule_options: { perform_in: 5 }
```

## Failure

If you pass invalid parameters to sidekiq, you will get an immediate return with the error message.
```sh
>> result = RegularAction.async_call(message: 'hello!', sidekiq_schedule_options: "error")
#<Interactor::Context key="value", sidekiq_options="bad error message", error="undefined method `transform_keys' for \"bad error message\":String">
>> result.failure?
true
>> Sidekiq::Queues.jobs_by_queue
{}
```

## Interactor::Async

Now you need an interactor to always assume asynchronous behavior using: **Interator::Async**.

#### Passing handle sidekiq exception

When executing the perform method in sidekiq there may be a problem, thinking about it we have already made it possible for you to handle this error.
**If the context is failed during invocation of the interactor in background, the Interactor::Failure is raised**.


```ruby
class AsyncAction
  include Interactor::Async

  def call
    { context: context.variable }
  end

  def self.sidekiq_options
    { queue: :low_priority }
  end
    
  def self.sidekiq_schedule_options
    { perform_in: 5 }
  end
  
  def self.handle_sidekiq_exception(error)
    # Integrate with Application Monitoring and Error Tracking Software
  end
end
```

## Compatibility

The same Ruby versions as Sidekiq are offically supported, but it should work
with any 2.x syntax Ruby including JRuby and Rubinius.

## Running Specs

```
bundle exec rspec
```

## License

MIT
