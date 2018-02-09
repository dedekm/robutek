require "rexml/document"
require "savage"

module SvgTool
  class Matrix
    def initialize(a, b, c, d, e, f)
      @a = a.to_f
      @b = b.to_f
      @c = c.to_f
      @d = d.to_f
      @e = e.to_f
      @f = f.to_f
    end
    
    def self.fromString(s)
      type = s.match(/(?:^|(?:[.!?]\s))(\w+)/).to_s
      values = s.match(/(?<=\().+?(?=\))/).to_s.split(/[\s,]+/).map(&:to_f)
      
      case type
      when 'translate'
        self.translate(values[0], values[1])
      when 'scale'
        self.scale(values[0], values[1])
      when 'matrix'
        self.new(values[0], values[1], values[2], values[3], values[4], values[5])
      end
    end
    
    def self.translate(x,y)
      self.new(1, 0, 0, 1, x, y)
    end
    
    def self.scale(x,y = nil)
      self.new(x, 0, 0, y || x, 0, 0)
    end
    
    def transformPoint(point)
      point.x = x(point.x,point.y)
      point.y = y(point.x,point.y)
      
      point
    end
    
    def x(x,y)
      x * @a + y * @c + @e
    end
    
    def y(x,y)
      x * @b + y * @d + @f
    end
    
    def to_s
    "matrix #{@a} #{@b} #{@c} #{@d} #{@e} #{@f}"
    end
  end
  
  class Svg
    attr_reader :paths, :doc, :filepath, :size
    
    def initialize( filepath )
      @filepath = filepath
      @size = Savage::Directions::Point.new
      
      file = File.new filepath
      @doc = REXML::Document.new file
      @paths = parse(@doc)
    end
    
    private
    
    def parse( doc )
      ungroup(doc)
    end
    
    def ungroup(element, matrixes = [])
      paths = []
      
      viewbox = element.attributes['viewBox']
      if viewbox
        viewbox = viewbox.split(' ')
        @size.x = viewbox[2].to_f - viewbox[0].to_f
        @size.y = viewbox[3].to_f - viewbox[1].to_f
      end
      
      # element has transform attribute (group)
      if element.attributes['transform']
        transform = element.attributes['transform'].split(/\s+(?![^\[]*\]|[^(]*\)|[^\{]*})/)
        
        matrixes.push []
        transform.each do |t|
          matrixes.last.push Matrix.fromString(t)
        end
      end
      
      # element has drawing commands (line)
      element.elements.each("line") do |line|
        path = Savage::Path.new do |p|
          p.move_to line.attributes['x1'].to_f, line.attributes['y1'].to_f
          p.line_to line.attributes['x2'].to_f, line.attributes['y2'].to_f
        end

        paths.push({path: path, matrixes: matrixes.clone.flatten})
      end
      
      # element has drawing commands (rect)
      element.elements.each("rect") do |rect|
        x = rect.attributes['x'].to_f
        y = rect.attributes['y'].to_f
        w = rect.attributes['width'].to_f
        h = rect.attributes['height'].to_f
        path = Savage::Path.new do |p|
          p.move_to x, y
          p.line_to x + w, y
          p.line_to x + w, y + h
          p.line_to x, y + h
          p.close_path
        end
        
        paths.push({path: path, matrixes: matrixes.clone.flatten})
      end
      
      # element has drawing commands (polyline)
      element.elements.each("polyline") do |pl|
        points = pl.attributes['points'].split(' ')
        path = Savage::Path.new do |p|
          point = points.shift.split(',')
          p.move_to point[0].to_f, point[1].to_f
          points.each do |point|
            point = point.split(',')
            p.line_to point[0].to_f, point[1].to_f
          end
        end

        paths.push({path: path, matrixes: matrixes.clone.flatten})
      end
      
      # element has drawing commands (polygon)
      element.elements.each("polygon") do |pl|
        points = pl.attributes['points'].split(' ')
        path = Savage::Path.new do |p|
          point = points.shift.split(',')
          p.move_to point[0].to_f, point[1].to_f
          points.each do |point|
            point = point.split(',')
            p.line_to point[0].to_f, point[1].to_f
          end
          p.close_path
        end

        paths.push({path: path, matrixes: matrixes.clone.flatten})
      end

      # element has drawing commands (path)
      element.elements.each("path") do |path|
        
        path = Savage::Parser.parse path.attributes['d']
        actualPosition = Savage::Directions::Point.new

        path.subpaths.each do |s|
          s.directions.each do |d|
            break if d.command_code.downcase == "z"
            
            if d.absolute?
              actualPosition.x = d.target.x
              actualPosition.y = d.target.y
            else
              d.target.x += actualPosition.x
              d.target.y += actualPosition.y
              
              if d.command_code.downcase == "q"
                d.control.x += actualPosition.x
                d.control.y += actualPosition.y
              end
              
              if d.command_code.downcase == "c"
                d.control_1.x += actualPosition.x
                d.control_1.y += actualPosition.y
                d.control_2.x += actualPosition.x
                d.control_2.y += actualPosition.y
              end
              
              actualPosition.x = d.target.x
              actualPosition.y = d.target.y
            end
          end
        end
        paths.push({path: path, matrixes: matrixes.clone.flatten})
      end
      
      element.elements.each do |group|
          paths += ungroup(group, matrixes)
      end
      
      matrixes.pop
      
      paths
    end
  end
end
