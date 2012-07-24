require 'resolv'

module Heroku
  module Helpers
    def run_check(message, options={})
      display("#{message}... ", false)
      ret = yield
      if ret
        display("Passsed", false)
      elsif ret == false
        display("Failed", false)
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
  VALID_HOSTNAMES = ["herokuapp.com", "herokussl.com", "heroku-shadowapp.com", "heroku-shadowssl.com"]

  def cnames(dname)
    col = []
    Resolv::DNS.open do |dns|
      res = dns.getresources(dname, Resolv::DNS::Resource::IN::CNAME)
      col << res.map {|r| r.name.to_s}
    end
    col.flatten
  end

end

module Checks
  extend self

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
      ao["name"].include?("heroku-postgresql")
    end
  end

  def dyno_redundancy?(app_name)
    web_dynos(app_name).length >= 2
  end

  def cedar?(app_name)
    api.get_app(app_name).body["stack"] == "cedar"
  end

  def prod_db?(app_name)
    heroku_pgdb(app_name).length >= 1
  end

  def follower_db?(app_name)
    heroku_pgdb(app_name).length >= 2
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
      Dns.cnames(dname).all? {|cname| Dns::VALID_HOSTNAMES.include?(cname)}
    end
  end

  def log_drains?(app_name)
    !heroku.list_drains(app_name).body.include?("No")
  end

end

class Heroku::Command::Production < Heroku::Command::Base
  include Checks

  def check
    run_check("Checking Cedar") {cedar?(app)}
    run_check("Dyno Redundancy") {dyno_redundancy?(app)}
    run_check("Production Database") {prod_db?(app)}
    run_check("Follower Database") {follower_db?(app)}
    run_check("SSL Endpoint") {ssl_endpoint?(app)}
    run_check("DNS Configuration") {dns_cname?(app)}
    run_check("Log Drains") {log_drains?(app)}
  end

end
