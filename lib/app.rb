require 'httparty'
require 'json'
require 'redis'

def main
  repos, search = get_search_terms

  cache = Redis.new
  matches = cache.get "#{repos}:#{search}"

  if matches.nil?
    search_online(repos, search)
    cache.set "#{repos}:#{search}", matches
  end

  display_results(matches)
end

def search_online(repos, search)
  matches = {}
  repos_response = HTTParty.get "https://api.github.com/search/repositories?q=#{repos}&sort=updated&order=desc"

  users = get_users(repos)

  users.each do |user|
    search_repo(user, search, matches)
    break if call_limit_reached?(search_response)
  end

  matches = matches.to_json
end

def get_search_terms
  puts 'Enter a repo search term: '
  repos = gets.chomp

  puts 'Enter a code search term: '
  search = gets.chomp

  [repos, search]
end

def get_users(repos)
  repos_response = HTTParty.get "https://api.github.com/search/repositories?q=#{repos}&sort=updated&order=desc"

  repos_response['items'].map { |repo| repo['owner']['login'] }
end

def search_repo(user, search, matches)
  search_response = get_search_results(user, search)

  if results_exist?(search_response)
    add_results_to_list(matches, user, search_response)
  else
    puts 'No matches found.' unless call_limit_reached?
  end
end

def get_search_results(user, search)
  HTTParty.get "https://api.github.com/search/code?q=#{search}+in:file+user:#{user}",
    headers: { "User-Agent" => 'Ruby', Accept: 'application/vnd.github.v3.text-match+json' }
end

def call_limit_reached?(search_response)
  search_response.key? 'message'
end

def results_exist?(response)
  response.key?('total_count') and response['total_count'] > 0
end

def add_results_to_list(matches, user, search_response)
  matches[user] = search_response['items'].map do |item|
    { fragments: item['text_matches'].map { |match| match['fragment'] } }
  end
end

def display_results(matches)
  JSON.parse(matches).each do |user|
    user_matches = user[1].map { |fragment| fragment['fragments'].first }
    puts "User: #{user[0]}, Matches: #{user_matches.join ''}"
  end
end

main if __FILE__ == $PROGRAM_NAME
