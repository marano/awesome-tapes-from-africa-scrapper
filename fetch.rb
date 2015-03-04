require 'json'
require 'fileutils'
require 'rubygems'
require 'capybara'
require 'capybara/dsl'
require 'pry'

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end

Capybara.run_server = false
Capybara.current_driver = :chrome
Capybara.app_host = 'http://www.awesometapes.com/'

include Capybara::DSL

visit('/')
categories = [
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
][0..1]

links = page.find('#content_inside').all('.post_box a').map { |link| link['href'] }

sound_cloud_address = 'http://w.soundcloud.com/player/'

data = []
data = categories.map do |category|
  visit(category[:href])

  should_keep_scrolling = true
  while should_keep_scrolling
    page.execute_script('window.scrollTo(0, 1000000000)')
    is_spinning = page.has_css?('#infscr-loading', visible: true)
    if !is_spinning
      should_keep_scrolling = false
    end
    while page.has_css?('#infscr-loading', visible: true)
      sleep 0.5
    end
  end

  albums = []

  links[0..1].each do |link|
    visit(link)
  
    is_sound_cloud = page.all('iframe').any? do |iframe|
      iframe['src'].include?(sound_cloud_address)
    end
  
    if !is_sound_cloud
      content = page.find('.single_left')
  
      header = content.find('h1').text
  
      details = {
        category: category[:title]
      }
  
      if header.include?('—')
        album_data = header.split('—')
        details[:artist] = album_data[0].strip
        details[:title] = album_data[1].strip
      else
        details[:title] = header.strip
      end
  
      details[:tracks] = content.all('a').map do |link|
        {
          title: link.text.strip,
          href: link['href']
        }
      end
  
      albums << details
    end
    
  end

  {
    category: category[:title],
    albums: albums
  }
end

FileUtils.mkdir_p('output')
output_file = 'output/data.json'
FileUtils.rm_rf(output_file)
File.open(output_file, 'w') { |file| file.write(JSON.generate(data)) }
