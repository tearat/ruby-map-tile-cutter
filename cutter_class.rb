require 'RMagick'
require 'fileutils'
require 'colorize'

class Cutter
  include Magick

  attr_reader :filename, :tile_size, :ext, :tiles_path, :bg_color

  DEFAULT_RUN_OPTIONS = {
    filename: 'test.jpg',
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
    puts "Initial image size:           " + "#{width}px #{height}px".yellow

    columns = (width.to_f / tile_size).ceil
    rows = (height.to_f / tile_size).ceil

    max_chunks_count = [columns, rows].max
    puts "Calculated chunks count:      " + "#{max_chunks_count}".yellow
    max_exp = 1
    max_exp *= 2 while max_exp < max_chunks_count
    puts "Calculated zoom levels:       " + "#{max_exp}".yellow

    new_size = max_exp * tile_size

    blank = Magick::Image.new(new_size, new_size)
    blank.background_color = bg_color
    blank.erase!
    resized_max = blank.composite(img, CenterGravity, AtopCompositeOp)
    puts "Resized image size at zoom 0: " + "#{resized_max.columns}px #{resized_max.rows}px".yellow
    puts

    @images = []
    z = 0
    exp = 1
    while exp <= max_exp
      puts "Resizing image to zoom #{z}..."
      zoom_size = exp * tile_size
      new_image = resized_max.resize_to_fit(zoom_size, zoom_size)
      @images << {
        zoom: z,
        chunks: exp,
        image: new_image
      }
      z += 1
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
      chunks_count = img[:chunks]
      x = 0
      while x < chunks_count
        y = 0
        while y < chunks_count
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
