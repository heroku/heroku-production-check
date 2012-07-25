require 'resolv'
require 'uri'

module Heroku
  module Helpers
    def run_check(message, fix_url, options={})
      display("#{message}".ljust(30), false)
      ret = yield
      if ret
        display("Passed", false)
      elsif ret == false
        display("Failed \t remedy: #{fix_url}", false)
      else
        display("Skipped", false)
      end
      display
      ret
    end
  end
end

module Dns
  extend self

  def cnames(dname)
    col = []
    Resolv::DNS.open do |dns|
      res = dns.getresources(dname, Resolv::DNS::Resource::IN::CNAME)
      col << res.map {|r| r.name.to_s}
    end
    col.flatten
  end

  def a_records(dname)
    col = []
    Resolv::DNS.open do |dns|
      res = dns.getresources(dname, Resolv::DNS::Resource::IN::A)
      col << res.map {|r| r.address.to_s}
    end
    col.flatten
  end

end

module Checks
  extend self

  HEROKU_DOMAINS = ["herokuapp.com", "herokussl.com", "heroku-shadowapp.com", "heroku-shadowssl.com"]
  HEROKU_IPS = ["75.101.145.87", "75.101.163.44", "174.129.212.2", "50.16.232.130", "50.16.215.196"]

  # Attempt to access dynos of the app.
  # If the current user does not have access to the app,
  # an error message will be displayed.
  def can_access?(app_name)
    web_dynos(app_name)
  end

  def domain_names(app_name)
    api.get_domains(app_name).body.map {|d| d["domain"]}
  end

  def web_dynos(app_name)
    api.get_ps(app_name).body.select do |ps|
      ps["process"].include?("web")
    end
  end

  def heroku_pgdb(app_name)
    api.get_addons(app_name).body.select do |ao|
      ao["name"].include?("heroku-postgresql") &&
        !ao["name"].include?("dev")
    end
  end

  def dyno_redundancy?(app_name)
    api.get_ps(app_name).body.reject do |ps|
      ps["process"] =~ /run\.\d+/
    end.group_by do |ps|
      ps["process"]
    end.all? do |process, col|
      col.length >= 2
    end
  end

  def cedar?(app_name)
    api.get_app(app_name).body["stack"] == "cedar"
  end

  def database_url(app_name)
    api.get_config_vars(app_name).body["DATABASE_URL"]
  end

  def postgres_urls(app_name)
    api.get_config_vars(app_name).body.select do |k,v|
      k.downcase.include?("heroku_postgres")
    end
  end

  # Skip check if there is not DATABASE_URL set on the app.
  # Otherweise we will check to see if a Heroku PostgreSQL prod db is installed.
  def prod_db?(app_name)
    return nil unless database_url(app_name)
    heroku_pgdb(app_name).length >= 1
  end

  # Follower databases have the same username, password, and database name.
  # The only difference between a follower url and a master url is the host.
  # Skip if the app doesn't have a database_url set in the config.
  def follower_db?(app_name)
    return nil unless database_url(app_name)
    uri = URI.parse(database_url(app_name))
    postgres_urls(app_name).select do |name, url|
      tmp_uri = URI.parse(url)
      [:user, :password, :path].all? do |k|
        uri.send(k) == tmp_uri.send(k)
      end
    end.length >= 2
  end

  def web_app?(app_name)
    web_dynos(app_name).length >= 1
  end

  def ssl_endpoint?(app_name)
    return nil unless web_app?(app_name)
    return nil if domain_names(app_name).empty?
    api.get_addons(app_name).body.select do |ao|
      ao["name"].include?("ssl:endpoint")
    end.length >= 1
  end

  def dns_cname?(app_name)
    return nil unless web_app?(app_name)
    domain_names(app_name).all? do |dname|
      if HEROKU_DOMAINS.any?{|hd| dname.include?(hd)}
        true
      else
        Dns.cnames(dname).all? do |cname|
          HEROKU_DOMAINS.any? {|hd| cname.include?(hd)}
        end
      end
    end
  end

  def dns_a_record?(app_name)
    return nil unless web_app?(app_name)
    domain_names(app_name).all? do |dname|
      Dns.a_records(dname).none? {|ip| HEROKU_IPS.include?(ip)}
    end
  end

  def dns?(app_name)
    dns_cname?(app_name) && dns_a_record?(app_name)
  end

  def log_drains?(app_name)
    !heroku.list_drains(app_name).body.include?("No")
  end

end

# check the production status of an app
#
class Heroku::Command::Production < Heroku::Command::Base
  include Checks

  # check
  #
  # check the production status of an app
  def check
    display("=== Production check for #{app}")
    if can_access?(app)
      run_check("Cedar", "http://bit.ly/NIMhag") {cedar?(app)}
      run_check("Dyno Redundancy","http://bit.ly/SSHYev"){dyno_redundancy?(app)}
      run_check("Production Database", "http://bit.ly/PWsbrJ") {prod_db?(app)}
      run_check("Follower Database", "http://bit.ly/MGsk39") {follower_db?(app)}
      run_check("SSL Endpoint", "http://bit.ly/PfzI7x") {ssl_endpoint?(app)}
      run_check("DNS Configuration", "http://bit.ly/PfzI7x") {dns?(app)}
      run_check("Log Drains", "http://bit.ly/MGtYSq") {log_drains?(app)}
    end
  end

end
