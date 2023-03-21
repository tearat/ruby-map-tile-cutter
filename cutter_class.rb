require 'RMagick'
require 'fileutils'
require 'colorize'

class Cutter
  include Magick

  attr_reader :filename, :tile_size, :ext, :tiles_path, :bg_color

  DEFAULT_RUN_OPTIONS = {
    filename: 'map.jpg',
    tile_size: 256,
    ext: 'png',
    bg_color: '#111',
    tiles_path: 'tiles',
    make_tiles: true
  }

  def initialize(options)
    options = DEFAULT_RUN_OPTIONS.merge(options)

    @filename = options[:filename]
    @tile_size = options[:tile_size]
    @ext = options[:ext]
    @tiles_path = options[:tiles_path]
    @bg_color = options[:bg_color]

    @resizing_time = 0
    @tiles_time = 0
    @full_time = 0

    puts '🗺️ Maps tile cutter v1.0'.green
    puts
    puts 'Filename:   ' + "#{filename}".yellow
    puts 'Tile size:  ' + "#{tile_size} px".yellow
    puts 'Extension:  ' + "#{ext}".yellow
    puts 'BG color:   ' + "#{bg_color}".yellow
    puts 'Tiles path: ' + "/#{tiles_path}".yellow
  end

  # Generate temp images with required resolutions
  def make_templates
    start = Time.now
    img = ImageList.new(filename)
    width = img.columns
    height = img.rows
    puts
    puts "✔️ Make templates".green
    puts "Initial image size:   " + "#{width}px x #{height}px".yellow

    max_side = [width, height].max
    max_side_chunks = (max_side.to_f / tile_size).ceil
    puts "Chunks count:         " + "#{max_side_chunks}".yellow + " (ceil of max side (#{max_side}) / tile_size (#{tile_size})"

    max_zoom = 1
    max_zoom *= 2 while max_zoom < max_side_chunks
    puts "Zoom levels:          " + "#{max_zoom}".yellow + " (nearest power of 2 >= max_side_chunks)"

    new_size = max_zoom * tile_size
    puts "New image size:       " + "#{new_size}px x #{new_size}px".yellow + " (max_zoom (#{max_zoom}) * tile_size (#{tile_size}))"

    blank = Magick::Image.new(new_size, new_size)
    blank.background_color = bg_color
    blank.erase!
    resized_max = blank.composite(img, CenterGravity, AtopCompositeOp)
    puts "Created zoom 0 image: " + "#{new_size}px x #{new_size}px".yellow
    puts

    @images = []

    zoom = 0
    exp = 1
    while exp <= max_zoom
      resize_size = exp * tile_size
      new_image = resized_max.resize_to_fit(resize_size, resize_size)
      @images << {
        zoom: zoom,
        chunks_count: exp,
        image: new_image
      }
      zoom += 1
      exp *= 2
    end

    puts
    puts @images

    stop = Time.now
    @resizing_time = stop - start
    @full_time += @resizing_time
    @resizing_time
  end

  # Create or empty tiles folder and force tiles making
  def make_tiles
    start = Time.now
    puts
    puts "✔️ Make tiles".green
    FileUtils.mkdir tiles_path unless File.exist? tiles_path
    FileUtils.rm_rf Dir.glob("#{tiles_path}/*") if File.exist? tiles_path
    x = 0
    y = 0
    tiles_done = 0
    @images.each_with_index do |img, z|
      puts "Making tiles for zoom #{z}"
      x = 0
      while x < img[:chunks_count]
        y = 0
        while y < img[:chunks_count]
          make_tile(x, y, img)
          tiles_done += 1
          y += 1
        end
        x += 1
      end
    end

    puts "Tiles created: " + "#{tiles_done}".yellow

    stop = Time.now
    @tiles_time = stop - start
    @full_time += @tiles_time
    @tiles_time
  end

  # Generate chunk and save it to tiles folder
  def make_tile(x, y, img)
    x_offset = x * tile_size
    y_offset = y * tile_size
    z = img[:zoom]
    chunk = img[:image].crop(x_offset, y_offset, tile_size, tile_size)
    FileUtils.mkdir "#{tiles_path}/#{z}" unless File.exist? "#{tiles_path}/#{z}"
    FileUtils.mkdir "#{tiles_path}/#{z}/#{x}" unless File.exist? "#{tiles_path}/#{z}/#{x}"
    chunk.write("#{tiles_path}/#{z}/#{x}/#{y}.#{ext}")
  end

  def show_time
    puts
    puts '⏱️ Execution time'.green
    puts "Resizing:     " + "#{@resizing_time.ceil} s".yellow if @resizing_time
    puts "Saving tiles: " + "#{@tiles_time.ceil} s".yellow if @tiles_time
    puts "Full:         " + "#{@full_time.ceil} s".yellow if @full_time
  end
end
