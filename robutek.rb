require 'dino'
require_relative "bresenham"
require_relative "svg_tool"

class Robutek
  # WIP 
  MULTIPLIER = 40
  def initialize( base, margin = 100 )
    @base = base
    @margin = margin
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
    
    @current = Savage::Directions::Point.new(@base/2, 350)
    @start = @current.clone
    @steps = []
    
    puts 'Board found and connected!'
  end
  
  def setLeftStepper( step, dir )
    @stepperL = Dino::Components::Stepper.new(board: @board, pins: { step: step, direction: dir })
  end
  
  def setRightStepper( step, dir )
    @stepperR = Dino::Components::Stepper.new(board: @board, pins: { step: step, direction: dir })
  end
  
  def setServo( pin )
    @servo = Dino::Components::Servo.new(pin: pin, board: @board)
    servoSwitch :up
  end
  
  def loadSvg path
    @svg = SvgTool::Svg.new path
    
    baseMatrix = [ SvgTool::Matrix.scale( (@base - @margin * 2) / @svg.size.x ) ]
    baseMatrix.push SvgTool::Matrix.translate(@margin, @margin)
    
    @svg.paths.each do |path|
      path[:path].subpaths.each do |subpath|
        path[:matrixes] = path[:matrixes] + baseMatrix
        
        subpath.directions.each do |direction|
          target = direction.command_code.capitalize != 'Z' ? direction.target.clone : subpath.directions.first.target.clone

          path[:matrixes].each do |matrix|
            target = matrix.transformPoint(target)
          end
          
          case direction.command_code.capitalize
            when "M"
              steps = moveTo(target.x, target.y)
            when "L"
              steps = lineTo(target.x, target.y)
            when "Z"
              steps = lineTo(target.x, target.y)
            when "Q"
              control = direction.control.clone
              
              path[:matrixes].each do |matrix|
                control = matrix.transformPoint(control)
              end
              
              steps = quadBezierTo(control.x, control.y, target.x, target.y)
            when "C"
              control_1 = direction.control_1.clone
              control_2 = direction.control_2.clone
              
              path[:matrixes].each do |matrix|
                control_1 = matrix.transformPoint(control_1)
                control_2 = matrix.transformPoint(control_2)
              end
              
              steps = cubicBezierTo(control_1.x, control_1.y, control_2.x, control_2.y, target.x, target.y)
          end
          
          @current = target.clone
          
          @steps += steps
        end
      end
    end
    @steps += moveTo(@start.x, @start.y)
  end
  
  def work
    raise "Steppers aren't set up!" if @stepperL.nil? && @stepperR.nil?
    raise "Left stepper isn't set up!" if @stepperL.nil?
    raise "Right stepper isn't set up!" if @stepperR.nil?
    raise "Servo isn't set up!" if @servo.nil?
    
    @steps.each do |step|
      if step[:servo]
        servoSwitch step[:servo]
      else
        @stepperL.step_cc if step[:l] == -1
        @stepperL.step_cw if step[:l] == 1
        
        @stepperR.step_cc if step[:r] == 1
        @stepperR.step_cw if step[:r] == -1
        sleep 0.001
      end
    end
    
    servoSwitch :up
  end
  
  private
  
  def moveTo(x0, y0)
    l0 = leg(@current.x, @current.y)
    r0 = leg(@base - @current.x, @current.y)
    l1 = leg(x0, y0)
    r1 = leg(@base - x0, y0)
    
    puts "move #{@current.x}, #{@current.y} > #{x0} #{y0}"
    steps = [{ servo: :up }]
    steps += toSteps(Bresenham.line(l0, r0, l1, r1))
  end
  
  def lineTo(x0, y0)
    l0 = leg(@current.x, @current.y)
    r0 = leg(@base - @current.x, @current.y)
    l1 = leg(x0, y0)
    r1 = leg(@base - x0, y0)
    
    puts "line #{@current.x}, #{@current.y} > #{x0} #{y0}"
    steps = [{ servo: :down }]
    steps += toSteps(Bresenham.line(l0, r0, l1, r1))
  end
  
  def quadBezierTo(x0, y0, x1, y1)
    l0 = leg(@current.x, @current.y)
    r0 = leg(@base - @current.x, @current.y)
    l1 = leg(x0, y0)
    r1 = leg(@base - x0, y0)
    l2 = leg(x1, y1)
    r2 = leg(@base - x1, y1)
    
    puts "quad curve #{@current.x}, #{@current.y} > #{x0} #{y0} > #{x1} #{y1}"
    
    steps = [{ servo: :down }]
    steps += toSteps(Bresenham.quadBezier(l0, r0, l1, r1, l2, r2))
  end
  
  def cubicBezierTo(x0, y0, x1, y1, x2, y2)
    l0 = leg(@current.x, @current.y)
    r0 = leg(@base - @current.x, @current.y)
    l1 = leg(x0, y0)
    r1 = leg(@base - x0, y0)
    l2 = leg(x1, y1)
    r2 = leg(@base - x1, y1)
    l3 = leg(x2, y2)
    r3 = leg(@base - x2, y2)
    
    puts "cubic curve #{@current.x}, #{@current.y} > #{x0} #{y0} > #{x1} #{y1} > #{x2} #{y2}"
    
    steps = [{ servo: :down }]
    steps += toSteps(Bresenham.cubicBezier(l0, r0, l1, r1, l2, r2, l3, r3))
  end
  
  def servoSwitch direction
    if direction == :up && @servo.position == 0
      @servo.position = 75
      sleep 0.5
    elsif direction == :down && @servo.position == 75
      @servo.position = 0
      sleep 0.5
    end
  end
  
  def toSteps(values)
    return [{l: 0, r: 0}] if values.empty?
    
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
    ( Math.sqrt( a ** 2 + b ** 2 ) * MULTIPLIER ).round
  end
end

robutek = Robutek.new 750
robutek.setLeftStepper 12, 10
robutek.setRightStepper 4, 2
robutek.setServo 9

robutek.loadSvg 'test-path.svg'
robutek.work

puts 'DONE'
