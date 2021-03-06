require 'dino'
require_relative "bresenham"
require_relative "svg_tool"

require 'yaml'
# defaults
config = {
  'base' => 1000,
  'multiplier' => 10,
  'start' => {
    'y' => 250
  },
  'margin' => {
    'x' => 250,
    'y' => 250
  },
  'servo' => {
    'min' => 75,
    'max' => 0
  }
}
if File.exist?('config.yml')
  config.merge! YAML::load_file('config.yml')
else
  warn "Warning: 'config.yml' not found!"
end

class Robutek
  # WIP
  def initialize(opts = {})
    # FIXME: add warnings for missing opts
    @multiplier = opts[:multiplier] || 10
    @base = opts[:base]
    @margin = Savage::Directions::Point.new(opts[:margin][:x], opts[:margin][:y] || opts[:margin][:x])
    @servo_min = opts[:servo][:min]
    @servo_max = opts[:servo][:max]
    
    loop do
      begin
          @board = Dino::Board.new(Dino::TxRx::Serial.new)
      rescue Dino::BoardNotFound
          puts 'No board found!'
          puts '...'
          sleep 0.5
          retry
      end
      break if @board
    end
    
    @current = Savage::Directions::Point.new(opts[:start][:x] || @base/2, opts[:start][:y] || 250)
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
    
    baseMatrix = [ SvgTool::Matrix.scale( (@base - @margin.x * 2) / @svg.size.x ) ]
    baseMatrix.push SvgTool::Matrix.translate(@margin.x, @margin.y)
    
    @svg.paths.each do |path|
      path[:matrixes] = path[:matrixes] + baseMatrix
      
      path[:path].subpaths.each do |subpath|
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
    
    # puts "move #{@current.x}, #{@current.y} > #{x0} #{y0}"
    print '.'
    
    steps = [{ servo: :up }]
    steps += toSteps(Bresenham.line(l0, r0, l1, r1))
  end
  
  def lineTo(x0, y0)
    l0 = leg(@current.x, @current.y)
    r0 = leg(@base - @current.x, @current.y)
    l1 = leg(x0, y0)
    r1 = leg(@base - x0, y0)
    
    # puts "line #{@current.x}, #{@current.y} > #{x0} #{y0}"
    print '.'
    
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
    
    # puts "quad curve #{@current.x}, #{@current.y} > #{x0} #{y0} > #{x1} #{y1}"
    print '.'
    
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
    
    # puts "cubic curve #{@current.x}, #{@current.y} > #{x0} #{y0} > #{x1} #{y1} > #{x2} #{y2}"
    print '.'
    
    steps = [{ servo: :down }]
    steps += toSteps(Bresenham.cubicBezier(l0, r0, l1, r1, l2, r2, l3, r3))
  end
  
  def servoSwitch direction
    if direction == :up && @servo.position == 0
      @servo.position = @servo_max
      sleep 0.5
    elsif direction == :down && @servo.position == 75
      @servo.position = @servo_min
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
    ( Math.sqrt( a ** 2 + b ** 2 ) * @multiplier ).round
  end
end

robutek = Robutek.new(
  base: config['base'],
  multiplier: config['multiplier'],
  margin: {
    x: config['margin']['x'],
    y: config['margin']['y']
  },
  start: {
    y: config['start']['y']
  },
  servo: {
    min: config['servo']['min'],
    max: config['servo']['max']
  }
)
  
robutek.setLeftStepper 12, 10
robutek.setRightStepper 4, 2
robutek.setServo 9

time = Time.now

filename = ARGV.first || 'test-path.svg'
print 'Preparing data'
robutek.loadSvg filename
puts 'done'
puts 'Drawing'
robutek.work

time = Time.at(Time.now - time)
puts time.strftime "Finished in %M min %S sec"
