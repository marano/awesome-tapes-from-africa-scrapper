require 'json'
require 'fileutils'
require 'open-uri'
require 'rubygems'
require 'pry'
require 'nokogiri'

SOUND_CLOUD_ADDRESS = 'http://w.soundcloud.com/player/'

@albums_data = []

def fetch_album_data_via_link(album_link)
  puts "Fetching album: #{album_link}"

  doc = Nokogiri::HTML(open(album_link), nil, 'UTF-8')
  
  is_sound_cloud = doc.css('iframe').any? do |iframe|
    iframe['src'].include?(SOUND_CLOUD_ADDRESS)
  end

  puts "is sound cloud: #{is_sound_cloud}"
  
  if !is_sound_cloud
    content = doc.at_css('.single_left')

    content.at_css('#jp-relatedposts').remove if content.at_css('#jp-relatedposts')
    if content.at_css('#comments')
      content.at_css('#comments').remove
      content.at_css('.commentlist').remove
    end
    content.at_css('#respond').remove if content.at_css('#respond')
  
    details = {
      href: album_link,
      sections: doc.css('meta[property="article:section"]').map { |meta| meta['content'] },
      tags: doc.css('meta[property="article:tag"]').map { |meta| meta['content'] }
    }

    header = content.at_css('h1').content
  
    if header.include?('—')
      album_data = header.split('—')
      details[:artist] = album_data[0].strip
      details[:title] = album_data[1].strip
    else
      details[:title] = header.strip
    end

    details[:tracks] = []

    content.css('a').select { |link| link['href'] && link['href'].end_with?('.mp3') }.each do |link|
      details[:tracks] << {
        title: link.content.strip,
        href: link['href']
      }
    end

    puts "Tracks fetched: #{details[:tracks].size}"

    details[:covers] = content.css('img').map do |image|
      {
        title: image['alt'].strip,
        src: image['src'].split('?')[0]
      }
    end

    puts "Covers fetched: #{details[:covers].size}"

    @albums_data << details unless details[:tracks].empty?
  end

  puts ""
end

def fetch_all_albums(archive_link)
  puts "Fetching archive (#{archive_link}) links..."
  doc = Nokogiri::HTML(open(archive_link), nil, 'UTF-8')

  albums_links = doc.css('.post_box a').map { |link| link['href'] }
  puts "Links fetched: #{albums_links.size}."
  puts ""

  albums_links.each do |album_link|
    fetch_album_data_via_link(album_link)
  end

  puts ""
end

def fetch_all_archives
  archives_list_url = 'http://www.awesometapes.com/nene-gale-bah-lega-fewndare/'
  doc = Nokogiri::HTML(open(archives_list_url), nil, 'UTF-8')
  doc.css('select[name="archive-dropdown"] option').each do |archive|
    archive_link = archive['value']
    fetch_all_albums(archive_link) if archive_link && archive_link != ''
  end
end

def save_data_to_file
  FileUtils.mkdir_p('output')
  output_file = 'output/data.json'
  FileUtils.rm_rf(output_file)
  File.open(output_file, 'w') { |file| file.write(JSON.pretty_generate(@albums_data)) }
end

fetch_all_archives
save_data_to_file
