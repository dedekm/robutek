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
      
      # FIXME: convert from other units
      multiplier = 1
      
      if element.attributes['width'] && !@size.x
        multiplier = 3.543307 if element.attributes['width'].index 'mm'
        @size.x = element.attributes['width'].match(/^\d*/)[0].to_f * multiplier
      end
      if element.attributes['height'] && !@size.y
        multiplier = 3.543307 if element.attributes['width'].index 'mm'
        @size.y = element.attributes['height'].match(/^\d*/)[0].to_f * multiplier
      end
      
      # element has transform attribute (group)
      if element.attributes['transform']
        transform = element.attributes['transform'].split(/\s+(?![^\[]*\]|[^(]*\)|[^\{]*})/)
        
        matrixes.push []
        transform.each do |t|
          matrixes.last.push Matrix.fromString(t)
        end
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
