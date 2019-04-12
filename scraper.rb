#!/bin/env ruby
# encoding: utf-8

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :members do
    member_urls.map { |memurl| Scraped::Scraper.new(memurl => MemberPage).scraper.to_h }
  end

  private

  def member_urls
    noko.css('a[href*="/FicheDepute"]/@href').map(&:text)
  end
end

class MemberPage < Scraped::HTML
  require 'cgi'
  decorator Scraped::Response::Decorator::CleanUrls

  field :id do
    CGI.parse(url.query)['ref'].first
  end

  field :name do
    box.css('h2.TitleOnly').text.tidy
  end

  field :birth_date do
    date_from(box.css('td.bgRed').first.text.tidy[/Date de naissance: (.*?) /, 1])
  end

  field :email do
    box.css('td.bgRed a[href*="mailto:"]/@href').text.sub('mailto:','').gsub('%20',' ').tidy
  end

  field :tel do
    box.css('td.bgRed').text.tidy[/Tél.:\s*([\s\d]+)/, 1].to_s.tidy
  end

  field :gender do
    return 'female' if box.text.tidy.include? 'Députée d'
    return 'male' if box.text.tidy.include? 'Député d'
    raise "No gender"
  end

  field :start_date do
    return '2018-10-30' if raw_start < '2018-10-30'
    raw_start
  end

  field :image do
    box.css('td.visu img/@src').text
  end

  field :term do
    '2018'
  end

  field :source do
    url.to_s
  end

  field :party_id do
    box.css('a.arrow/@href').text[/CodeGroupe=(\d+)/, 1]
  end

  field :party do
    PARTY[party_id] rescue binding.pry
  end

  private

  PARTY = Hash.new { |h, k| warn "Unknown party: #{k}" }.merge({
    '298' => 'DP',
    '299' => 'LSAP',
    '301' => 'déi Gréng',
    '297' => 'CSV',
    '300' => 'Alternativ Demokratesch Reformpartei',
    '302' => 'déi Lénk',
    '668' => 'Piraten',
  })

  def box
    noko.css('div#contentType1')
  end

  def raw_start
    date_from(box.css('div.fonctionsPersonneQualifiee li').text.tidy[/Députée?.*?depuis le (\d+\/\d+\/\d+)/, 1])
  end

  def date_from(str)
    return if str.to_s.empty?
    Date.parse(str).to_s rescue binding.pry
  end

  def url
    URI.parse super
  end
end

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

url = 'https://www.chd.lu/wps/portal/public/Accueil/OrganisationEtFonctionnement/Organisation/Deputes/DeputesEnFonction/!ut/p/z1/nZHJCsIwEIafxSfIZJKa5JjEmsaVtrjlIj2IFFq9iM9vEUXc6jK3gf__v1lIICvkigraFZwsSdgVx3JbHMr9rqiafhW66x725pnnCBBLBR4SPaLaMjtEsrgXSKsQvEtHQ0sjcFKQ8I0fpcwzp8exUjPTCCzN49Q0SXjvdyLlgIN4IGb5hDnGLn54Uxq-498AUWYBRWLSCObUK_4PX4PJ0DAAN8Vf-U-A3_zPgtB-nkmyrzdNSvi06IPgxaNbE5JrQtupPg1bh6p_Lpn70uvOCWS6a2I!/dz/d5/L2dBISEvZ0FBIS9nQSEh/'

Scraped::Scraper.new(url => MembersPage).store(:members)
