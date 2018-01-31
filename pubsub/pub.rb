# usage:
# ruby pub.rb channel username
class Publisher
  require 'rubygems'
  require 'redis'
  require 'json'
  require 'io/console'

  attr_reader :redis, :channel, :username

  def initialize(channel:, username:)
    @redis = Redis.new
    @channel = channel
    @username = username
    @data = { user: username }.freeze

    start_loop
  end

  private

  attr_reader :data

  def reset_console(last_msg)
    print `clear`
    puts "Last Message: \"#{last_msg}\"\n#{'=' * 40}\n\n" unless last_msg.nil?
    puts "Post message to channel: \"#{channel}\" (CTRL+c to quit)\n\n"
    print "\rMessage: "
  end

  def start_loop
    msg = nil
    loop do
      reset_console(msg)
      msg = STDIN.gets.chomp
      redis.publish channel, data.merge(msg: msg).to_json
    end
  end
end

if ARGV[0].nil? || ARGV[1].nil?
  puts "USAGE:\n$ ruby pub.rb channel username"
else
  trap :SIGINT do
    print `clear`
    puts "Exited channel \"#{ARGV[0]}\""
    exit 130
  end
  Publisher.new(channel: ARGV[0], username: ARGV[1])
end
