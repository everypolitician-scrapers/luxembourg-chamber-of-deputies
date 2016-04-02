#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
  # Nokogiri::HTML(open(url).read, nil, 'utf-8')
end

def date_from(str)
  return if str.to_s.empty?
  Date.parse(str).to_s rescue binding.pry
end

@party = Hash.new { |h, k| warn "Unknown party: #{k}".red }
@party['1472'] = 'DP'
@party['919']  = 'LSAP'
@party['1149'] = 'déi Gréng'
@party['1511'] = 'CSV'
@party['1081'] = 'Alternativ Demokratesch Reformpartei'
@party['1361'] = 'déi Lénk'

def gender_from(box)
  return 'female' if box.text.tidy.include? 'Députée d'
  return 'male' if box.text.tidy.include? 'Député d'
  raise "Can't find"
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('a[href*="/FicheDepute"]/@href').each do |mp|
    scrape_person(URI.join url, mp.text)
  end
end

def scrape_person(url)
  noko = noko_for(url)
  box = noko.css('div#contentType1')

  data = { 
    id: url.to_s[/ref=(\d+)/, 1],
    name: box.css('h1.swfReplace').text.tidy,
    birth_date: date_from(box.css('td.bgRed').text.tidy[/Née? le (.*)/, 1]),
    email: box.css('td.bgRed a[href*="mailto:"]/@href').text.sub('mailto:',''),
    tel: box.css('td.bgRed').text.tidy[/Tél.:\s*([\s\d]+)/, 1].to_s.tidy,
    gender: gender_from(box),
    start_date: date_from(box.css('div.fonctionsPersonnesQualifiees li').text.tidy[/Députée?.*?depuis le (\d+\/\d+\/\d+)/, 1]),
    image: box.css('td.visu img/@src').text,
    term: '2013',
    source: url.to_s,
    party_id: box.css('td.bgBrown img/@src').text[/ref=(\d+)/, 1],
  }
  data[:party] = @party[data[:party_id]]
  data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?
  data[:start_date] = '2013-11-13' if data[:start_date] < '2013-11-13'
  puts data[:name]
  ScraperWiki.save_sqlite([:id, :term], data)
end

term = { 
  id: '2013',
  name: '2013–',
  start_date: '2013-11-13',
  source: 'https://lb.wikipedia.org/wiki/Chamber',
}
ScraperWiki.save_sqlite([:id], term, 'terms')


scrape_list('http://www.chd.lu/wps/portal/public/!ut/p/b1/jY7LCoMwEEU_KZMxmmSpMcbYVoii1GzERSmCj03p99fuiqXU2V04594hnnTIJOU04oxciV-G53gfHuO6DNM7-6hPMW0ryxAMdwyw0AVv6jIwQbAB3ScglESwxp1PioZgBD_moxB1ZeKLlrJJwIKitXbJ1oTHfPhxMez8sFKAPE9cCC21ku3__wb-7Jf5Ot_I7Kcsy0T8AgGDGy8!/dl4/d5/L2dJQSEvUUt3QS80SmtFL1o2X0QyRFZSSTQyMDBFODkwSTBIQUwxQUMzQ0sy/')
