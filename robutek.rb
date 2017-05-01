require 'dino'
require_relative "bresenham"
require_relative "svg_tool"

class Robutek
  def initialize( base )
    @base = base
    loop do
      e = false
      begin
          @board = Dino::Board.new(Dino::TxRx::Serial.new)
      rescue Dino::BoardNotFound => e
          puts 'No board found!'
          puts '...'
          sleep 0.5
      end
      break if !e
    end
    
    @current = Savage::Directions::Point.new(base/2, 0)
    @steps = []
    
    puts 'Board found and connected!'
  end
  
  def setLeftStepper( step, dir )
    @stepperL = Dino::Components::Stepper.new(board: @board, pins: { step: step, direction: dir })
  end
  def setRightStepper( step, dir )
    @stepperR = Dino::Components::Stepper.new(board: @board, pins: { step: step, direction: dir })
  end
  
  def loadSvg path
    @svg = SvgTool::Svg.new path
    @svg.paths.each do |path|
      path.subpaths.each do |subpath|
        subpath.directions.each do |direction|
          target = direction.target
          
          case direction.command_code.capitalize
            when "M"
              steps = moveTo(target.x, target.y)
            when "L"
              steps = lineTo(target.x, target.y)
            when "Q"
              control = direction.control
              steps = quadBezierTo(control.x, control.y, target.x, target.y)
            when "C"
              control_1 = direction.control_1
              control_2 = direction.control_2
              steps = cubicBezierTo(control_1.x, control_1.y, control_2.x, control_2.y, target.x, target.y)
          end
          
          @current = target.clone
          
          @steps += steps
        end
      end
    end
  end
  
  private
  
  def moveTo(x0, y0)
    l0 = leg(@current.x, @current.y).round
    r0 = leg(@base - @current.x, @current.y).round
    l1 = leg(x0, y0).round
    r1 = leg(@base - x0, y0).round
    
    puts "move #{@current.x}, #{@current.y} > #{x0} #{y0}"
        
    steps = toSteps(Bresenham.line(l0, r0, l1, r1))
  end
  
  def lineTo(x0, y0)
    l0 = leg(@current.x, @current.y).round
    r0 = leg(@base - @current.x, @current.y).round
    l1 = leg(x0, y0).round
    r1 = leg(@base - x0, y0).round
    
    puts "line #{@current.x}, #{@current.y} > #{x0} #{y0}"
    
    steps = toSteps(Bresenham.line(l0, r0, l1, r1))
  end
  
  def quadBezierTo(x0, y0, x1, y1)
    l0 = leg(@current.x, @current.y).round
    r0 = leg(@base - @current.x, @current.y).round
    l1 = leg(x0, y0).round
    r1 = leg(@base - x0, y0).round
    l2 = leg(x1, y1).round
    r2 = leg(@base - x1, y1).round
    
    puts "quad curve #{@current.x}, #{@current.y} > #{x0} #{y0} > #{x1} #{y1}"
    
    steps = toSteps(Bresenham.quadBezier(l0, r0, l1, r1, l2, r2))
  end
  
  def cubicBezierTo(x0, y0, x1, y1, x2, y2)
    l0 = leg(@current.x, @current.y).round
    r0 = leg(@base - @current.x, @current.y).round
    l1 = leg(x0, y0).round
    r1 = leg(@base - x0, y0).round
    l2 = leg(x1, y1).round
    r2 = leg(@base - x1, y1).round
    l3 = leg(x2, y2).round
    r3 = leg(@base - x2, y2).round
    
    puts "cubic curve #{@current.x}, #{@current.y} > #{x0} #{y0} > #{x1} #{y1} > #{x2} #{y2}"
    
    steps = toSteps(Bresenham.cubicBezier(l0, r0, l1, r1, l2, r2, l3, r3))
  end
  
  def toSteps(values)
    ax = values.first[:x]
    ay = values.first[:y]
    values.map do |v| 
      l = v[:x] - ax
      ax = v[:x]
      
      r = v[:y] - ay
      ay = v[:y]
      
      {l: l, r: r}
    end
  end
  
  def leg(a,b)
    Math.sqrt(a ** 2 + b ** 2)
  end

end

robutek = Robutek.new 400
robutek.setLeftStepper 12, 10
robutek.setRightStepper 4, 2

robutek.loadSvg 'test-path.svg'

puts 'DONE'
