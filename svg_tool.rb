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
      
      def line_to_path(line)
        Savage::Path.new do |p|
          p.move_to line.attributes['x1'].to_f, line.attributes['y1'].to_f
          p.line_to line.attributes['x2'].to_f, line.attributes['y2'].to_f
        end
      end
      
      def rect_to_path(rect)
        x = rect.attributes['x'].to_f
        y = rect.attributes['y'].to_f
        w = rect.attributes['width'].to_f
        h = rect.attributes['height'].to_f
        Savage::Path.new do |p|
          p.move_to x, y
          p.line_to x + w, y
          p.line_to x + w, y + h
          p.line_to x, y + h
          p.close_path
        end
      end
      
      def poly_to_path(poly)
        points = poly.attributes['points'].split(' ')
        Savage::Path.new do |p|
          point = points.shift.split(',')
          p.move_to point[0].to_f, point[1].to_f
          points.each do |point|
            point = point.split(',')
            p.line_to point[0].to_f, point[1].to_f
          end
          p.close_path if poly.name == 'polygon'
        end
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
        
        path = nil
        case element.name
        when 'line'
          path = line_to_path(element)
        when 'rect'
          path = rect_to_path(element)
        when 'polyline'
          path = poly_to_path(element)
        when 'polygon'
          path = poly_to_path(element)
        when 'path'
          path = Savage::Parser.parse element.attributes['d']
          actualPosition = Savage::Directions::Point.new

          path.subpaths.each do |s|
            s.directions.each_with_index do |d, i|
              break if d.command_code.downcase == "z"
                          
              if d.command_code.downcase == "h"
                x = d.target
                x += actualPosition.x unless d.absolute?
                d = s.directions[i] = Savage::Directions::LineTo.new(x, actualPosition.y)
              elsif d.command_code.downcase == "v"
                y = d.target
                y += actualPosition.y unless d.absolute?
                d = s.directions[i] = Savage::Directions::LineTo.new(actualPosition.x, y)
              end
              
              unless d.absolute?
                d.target.x += actualPosition.x
                d.target.y += actualPosition.y
                
                if d.command_code.downcase == "q"
                  d.control.x += actualPosition.x
                  d.control.y += actualPosition.y
                end
                
                if d.command_code.downcase == "c"
                  d.control_1.x += actualPosition.x
                  d.control_1.y += actualPosition.y
                end
                
                if d.command_code.downcase == "s"
                  previous_d = s.directions[i - 1]
                  if previous_d && previous_d.respond_to?(:control_2)
                    d.control_1 = Savage::Directions::Point.new(
                      2 * actualPosition.x - previous_d.control_2.x,
                      2 * actualPosition.y - previous_d.control_2.y
                    )
                  else
                    d.control_1 = actualPosition.clone
                  end
                end
                
                if d.command_code.downcase == "c" || d.command_code.downcase == "s"
                  d.control_2.x += actualPosition.x
                  d.control_2.y += actualPosition.y
                end
              end

              actualPosition.x = d.target.x
              actualPosition.y = d.target.y
            end
          end
        end
        paths.push({path: path, matrixes: matrixes.clone.flatten}) if path
        
        element.elements.each do |group|
          paths += ungroup(group, matrixes)
        end
        
        matrixes.pop
        
        paths
      end
    end
end
