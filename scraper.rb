#!/bin/env ruby
# encoding: utf-8

require 'cgi'
require 'nokogiri'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def date_from(str)
  return if str.to_s.empty?
  Date.parse(str).to_s rescue binding.pry
end

@party = Hash.new { |h, k| warn "Unknown party: #{k}" }.merge({
  '298' => 'DP',
  '299' => 'LSAP',
  '301' => 'déi Gréng',
  '297' => 'CSV',
  '300' => 'Alternativ Demokratesch Reformpartei',
  '302' => 'déi Lénk',
  '668' => 'Piraten',
})

def gender_from(box)
  return 'female' if box.text.tidy.include? 'Députée d'
  return 'male' if box.text.tidy.include? 'Député d'
  raise "Can't find"
end

def list_data(url)
  noko = noko_for(url)
  noko.css('a[href*="/FicheDepute"]/@href').map do |mp|
    person_data(URI.join url, mp.text)
  end
end

def person_data(url)
  noko = noko_for(url)
  box = noko.css('div#contentType1')

  data = {
    id: CGI.parse(url.query)['ref'].first,
    name: box.css('h2.TitleOnly').text.tidy,
    birth_date: date_from(box.css('td.bgRed').first.text.tidy[/Née? le (.*)/, 1]),
    email: box.css('td.bgRed a[href*="mailto:"]/@href').text.sub('mailto:',''),
    tel: box.css('td.bgRed').text.tidy[/Tél.:\s*([\s\d]+)/, 1].to_s.tidy,
    gender: gender_from(box),
    start_date: date_from(box.css('div.fonctionsPersonnesQualifiees li').text.tidy[/Députée?.*?depuis le (\d+\/\d+\/\d+)/, 1]),
    image: box.css('td.visu img/@src').text,
    term: '2018',
    source: url.to_s,
    party_id: box.css('a.arrow/@href').text[/CodeGroupe=(\d+)/, 1],
  }
  data[:party] = @party[data[:party_id]]
  data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?
  data[:start_date] = '2018-10-30' if data[:start_date] < '2018-10-30'
  data
end

data = list_data('https://www.chd.lu/wps/portal/public/Accueil/OrganisationEtFonctionnement/Organisation/Deputes/DeputesEnFonction/!ut/p/z1/nZHJCsIwEIafxSfIZJKa5JjEmsaVtrjlIj2IFFq9iM9vEUXc6jK3gf__v1lIICvkigraFZwsSdgVx3JbHMr9rqiafhW66x725pnnCBBLBR4SPaLaMjtEsrgXSKsQvEtHQ0sjcFKQ8I0fpcwzp8exUjPTCCzN49Q0SXjvdyLlgIN4IGb5hDnGLn54Uxq-498AUWYBRWLSCObUK_4PX4PJ0DAAN8Vf-U-A3_zPgtB-nkmyrzdNSvi06IPgxaNbE5JrQtupPg1bh6p_Lpn70uvOCWS6a2I!/dz/d5/L2dBISEvZ0FBIS9nQSEh/')
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite([:id, :term], data)
