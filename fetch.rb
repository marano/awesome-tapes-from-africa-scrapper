require 'json'
require 'fileutils'
require 'open-uri'
require 'rubygems'
require 'capybara'
require 'capybara/dsl'
require 'pry'
require 'nokogiri'

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end

Capybara.run_server = false
Capybara.current_driver = :chrome
Capybara.app_host = 'http://www.awesometapes.com/'

include Capybara::DSL

@categories = [
  {title: '00s', href: '/category/00s/'},
  {title: '70s', href: '/category/70s/'},
  {title: '80s', href: '/category/80s/'},
  {title: '90s', href: '/category/90s/'},
  {title: 'ATFA News', href: '/category/atfa-news/'},
  {title: 'Central Africa', href: '/category/central-africa/'},
  {title: 'East Africa', href: '/category/east-africa/'},
  {title: 'North Africa', href: '/category/north-africa/'},
  {title: 'Southern Africa', href: '/category/southern-africa/'},
  {title: 'Uncategorized', href: '/category/uncategorized/'},
  {title: 'West Africa', href: '/category/west-africa/'}
]

SOUND_CLOUD_ADDRESS = 'http://w.soundcloud.com/player/'

@albums_data = []

def fetch_album_data_via_link(album_link, category)
  puts "Fetching album: #{album_link}"
  existing_album_data = @albums_data.find { |album_data| album_data[:href] == album_link }

  if existing_album_data
    puts "Album already in categories: #{existing_album_data[:categories]}"
    existing_album_data[:categories] << category[:title]
    puts "Album now in categories: #{existing_album_data[:categories]}"
  else
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
        categories: [category[:title]]
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

      content.css('a').select { |link| link['href'].end_with?('.mp3') }.each do |link|
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

      @albums_data << details
      puts ""
    end
  end
  puts ""
end

def fetch_all_categories
  @categories.each do |category|
    puts "Fetching category (#{category[:title]}) links..."
    visit(category[:href])

    should_keep_scrolling = true
    while should_keep_scrolling
      puts "Scrolling..."
      page.execute_script('window.scrollTo(0, 1000000000)')
      is_spinning = page.has_css?('#infscr-loading', visible: true)
      if !is_spinning
        should_keep_scrolling = false
      end
      while page.has_css?('#infscr-loading', visible: true)
        sleep 0.5
      end
    end

    puts ""

    albums_links = page.all('.post_box a').map { |link| link['href'] }
    puts "Links fetched: #{albums_links.size}."
    puts ""

    albums_links.each do |album_link|
      fetch_album_data_via_link(album_link, category)
    end
    puts ""
  end
end

def save_data_to_file
  FileUtils.mkdir_p('output')
  output_file = 'output/data.json'
  FileUtils.rm_rf(output_file)
  File.open(output_file, 'w') { |file| file.write(JSON.generate(@albums_data)) }
end

fetch_all_categories
save_data_to_file
