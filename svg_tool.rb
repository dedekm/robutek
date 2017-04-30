require "rexml/document"
require "savage"

module SvgTool
  class Svg
    def initialize( path )
      @path = path
      file = File.new path
      @doc = REXML::Document.new file
      @paths = parse(@doc)
    end
    
    private
    
    def parse( doc )
      ungroup(doc)
    end
    
    def ungroup(element)
      paths = []
      element.elements.each("path") do |path|
        
        path = Savage::Parser.parse path.attributes['d']
        actualPosition = Savage::Directions::Point.new
        puts path.subpaths
        path.subpaths.each do |s|
          s.directions.each do |d|
            ax = actualPosition.x
            ay = actualPosition.y
            
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
        paths.push path
      end
      
      element.elements.each do |group|
          paths += ungroup(group)
      end
      
      paths
    end
  end
end
