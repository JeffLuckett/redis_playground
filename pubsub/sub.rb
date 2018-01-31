# Usage
# ruby sub.rb [channel_1] [channel_2] ... [channel_n]

class Subscriber
  require 'rubygems'
  require 'redis'
  require 'json'
  require 'byebug'
  require 'set'

  attr_reader :redis, :queues

  DEFAULT_QUEUES = %w[control].freeze

  def initialize(queues)
    puts "Client #{Process.pid} Initializing"
    @redis = Redis.new
    @queues = Set.new(DEFAULT_QUEUES).merge(Array(queues))
    listen
  end

  private

  def listen
    redis.subscribe(*@queues) do |on|
      on.subscribe { |channel, subscriptions| handle_subscribed(channel, subscriptions) }
      on.message { |channel, msg| handle_message(channel, msg) }
      on.unsubscribe { |channel, subscriptions| handle_unsubscribed(channel, subscriptions) }
    end
  end

  def handle_control(msg)
    control_code, metadata = msg
    case control_code.to_sym
    when :sub   then subscribe(metadata)
    when :unsub then unsub(metadata)
    when :exit  then terminate(metadata)
    else
      show_available_commands(control_code)
    end
  end

  def handle_message(channel, msg)
    data = JSON.parse(msg)
    puts "##{channel} - [#{data['user']}]: #{data['msg']}"
    handle_control(data['msg'].split(':')) if channel == 'control'
  end

  def handle_subscribed(channel, subscriptions)
    puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
  end

  def handle_unsubscribed(channel, subscriptions)
    puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
    @queues.reject! { |q| q == channel }
    user_input('No subscriptions. Exit? (Y,N)') if (subscriptions - DEFAULT_QUEUES.size).zero?
  end

  def show_available_commands(command)
    puts "Unrecognized command #{command}"
    puts 'Available commands:'
    puts 'unsub:channel_name - unsubscribe from channel_name'
    puts 'sub:channel_name - subscribe to channel_name'
    puts 'exit:pid - tell subscriber with provided pid to leave'
  end

  def subscribe(where)
    if @queues.include?(where)
      puts "Already subscribed to #{where}"
    else
      puts "Client #{Process.pid} subscribing to #{where}"
      @queues << where
      redis.subscribe(where)
    end
  end

  def terminate(who)
    return unless Process.pid.to_s == who
    @quitting = true
    puts "Client #{Process.pid} exiting"
    exit
  end

  def unsubscribe(where)
    if DEFAULT_QUEUES.include?(where)
      puts "Cannot unsub from #{where} channel"
    elsif queues.include?(metadata)
      puts "Client #{Process.pid} unsubscribing from #{where}"
      redis.unsubscribe(where)
    else
      puts "Not subscribed to: #{where}"
    end
  end

  def user_input(initial_msg)
    print initial_msg + ' '
    loop do
      input = STDIN.gets.chomp
      case input.upcase
      when 'Y' then exit
      when 'N' then break
      else
        puts 'Enter "Y" or "N"'
      end
    end
  end
end

Subscriber.new(ARGV)
