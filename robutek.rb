require 'dino'
require_relative "bresenham"

class Robutek
  @base
  @board
  @stepperL
  @stepperR
  
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
    puts 'Board found and connected!'
  end
  
  def setLeftStepper( step, dir )
    @stepperL = Dino::Components::Stepper.new(board: @board, pins: { step: step, direction: dir })
  end
  def setRightStepper( step, dir )
    @stepperR = Dino::Components::Stepper.new(board: @board, pins: { step: step, direction: dir })
  end
end

robutek = Robutek.new 400
robutek.setLeftStepper 12, 10
robutek.setRightStepper 4, 2

puts values = Bresenham.cubicBezier(0, 0, 21, 21, 52, 42, 23, 13)

puts 'DONE'
