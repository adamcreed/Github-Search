require 'httparty'
require 'json'
require 'redis'

def main
  puts 'Enter a search term: '
  search = gets.chomp

  cache = Redis.new
  matches = cache.get search
  if matches.nil?
    response = HTTParty.get "https://api.github.com/search/code?q=#{search}+in:file+user:adamcreed",
      headers: { "User-Agent" => 'Ruby', Accept: 'application/vnd.github.v3.text-match+json' }

    if results_exist?(response)
      matches = response['items'].map do |item|
        { fragments: item['text_matches'].map { |match| match['fragment'] } }
      end

      cache.set search, matches.to_json
    end
  end

  JSON.parse(matches).each { |match| puts match['fragments'] }
end

def results_exist?(response)
  response.key?('total_count') and response['total_count'] > 0
end

main if __FILE__ == $PROGRAM_NAME
