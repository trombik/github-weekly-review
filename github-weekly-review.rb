#!/usr/bin/env ruby

require 'octokit'
require 'faraday-http-cache'
require 'optparse'
require 'ostruct'

def debug(text)

  STDOUT.puts text

end

def crit(text)

  STDERR.puts text
  exit 1

end

def compile_md

  repos = @client.organization_repositories(@options.organization, { sort: :pushed_at }).
    select { |r| r.name =~ /^ansible-(?:#{ Regexp.escape(@options.type) })-/ }
  markdown_text = ''

  repos.sort { |a, b| a.name <=> b.name }.each do |repo|

    mdfied_issues = []
    issues = @client.issues("#{ @options.organization }/#{ repo.name }", :state => 'open', :filter => 'all')
    issues.sort! { |a, b| b.number.to_i <=> a.number.to_i } # show newer issue first
    issues.each do |i|
      next if i.assignee
      mdfied_issues << "* [ ] issue %d: [%s](%s)" % [ i.number.to_i, i.title, i.html_url ]
    end
    if mdfied_issues.length > 0
      markdown_text += "# #{repo.name}\n\n"
      mdfied_issues.each do |i|
        markdown_text += "#{ i }\n"
      end
      markdown_text += "\n"
    end

  end
  markdown_text

end

stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, serializer: Marshal, shared_cache: false
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack

@options = OpenStruct.new(
  :type => 'role',
  :verbose => false,
  :organization => nil,
  :access_token => ENV['GITHUB_TOKEN_WEEKLY_REPORT'],
  :submit_to => nil,
  :dryrun => false,
)

OptionParser.new do |opts|

  opts.banner = "Usage: %s [options]" % [ Pathname.new(__FILE__).basename ]

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    @options.verbose = true
  end

  opts.on('-a', '--ansible [ TYPE ]', "type of repositories to fetch issues. either `role` or `project` default is #{ @options.type }", [ :role, :project ]) do |ansible|
    @options.type = ansible
  end

  opts.on('-o', '--organization ORGANIZATION', 'organization name. no default') do |org|
    @options.organization = org
  end

  opts.on('-s', '--submit_to ORGANIZATION/REPOSITORY', 'the repository to submit the weekly report to. no default') do |repo|
    @options.submit_to = repo
  end

  opts.on('-d', '--dryrun', "Do not submit the report. Just print the list to STDOUT. default is #{ @options.dryrun }" ) do |dryrun|
    @options.dryrun = true
  end

end.parse!

if ! @options.access_token
  crit "Environment variable `GITHUB_TOKEN_WEEKLY_REPORT` is not defined.\n Set the variable with yout github token"
end

@client = Octokit::Client.new(
  :access_token => @options.access_token,
  :auto_paginate => true,
)
user = @client.user
user.login

weekly_review = {
  :repository_to_submit => @options.submit_to,
  :title => "Weekly Review (%s)" % [ Time.new.strftime('%Y/%m/%d') ],
  :body => "A list of issues assigned to nobody.\n",
}

md = compile_md
if md
  weekly_review[:body] += md

  if @options.dryrun
    puts weekly_review[:body]
  else
    @client.create_issue(weekly_review[:repository_to_submit], weekly_review[:title], weekly_review[:body])
  end
end
