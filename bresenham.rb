class Bresenham
    EP = 0.01
  
    def self.assert(a)
        raise "Assertion failed in bresenham" if !a
    end
    
    def self.line(x0,y0,x1,y1)
        array = []
        
        dx =  (x1-x0).abs
        sx = x0<x1 ? 1 : -1
        dy = -1 * (y1-y0).abs
        sy = y0<y1 ? 1 : -1
        # error value e_xy
        err = dx+dy
        
        ax = x0
        ay = y0

        while true
            # puts "line x#{x0} y#{y0}"
            break if (x0 == x1 && y0 == y1)
            e2 = 2*err
            # x step
            if (e2 >= dy)
                err += dy
                x0 += sx
            end
            # y step
            if (e2 <= dx)
                err += dx
                y0 += sy
            end
            array.push({x: x0, y: y0})
        end
        array
    end
    
    # plot a limited quadratic Bezier segment
    def self.quadBezierSeg(x0, y0, x1, y1, x2, y2)
        array = []
        
        ax = x0 - 1
        ay = y0 - 1
      
        sx = x2-x1
        sy = y2-y1
        # relative values for checks
        xx = x0-x1
        yy = y0-y1
        # curvature
        cur = xx*sy-yy*sx

        # sign of gradient must not change
        assert(xx*sx <= 0 && yy*sy <= 0)
        # begin with shorter part
        # if (sx*sx+sy*sy > xx*xx+yy*yy)
        #     # swap P0 P2
        #     x2 = x0
        #     x0 = sx+x1
        #     y2 = y0
        #     y0 = sy+y1
        #     cur = -cur
        # end
        # no straight line
        if (cur != 0)
            # x step direction
            xx += sx
            xx *= sx = x0 < x2 ? 1 : -1
            # y step direction
            yy += sy
            yy *= sy = y0 < y2 ? 1 : -1
            # differences 2nd degree
            xy = 2*xx*yy
            xx *= xx
            yy *= yy
            # negated curvature?
            if (cur*sx*sy < 0)
                xx = -xx
                yy = -yy
                xy = -xy
                cur = -cur
            end
            # differences 1st degree
            dx = 4.0*sy*cur*(x1-x0)+xx-xy
            dy = 4.0*sx*cur*(y0-y1)+yy-xy
            # error 1st step
            xx += xx
            yy += yy
            err = dx+dy+xy
            begin
                # plot curve
                # puts "x#{x0} y#{y0}"
                # last pixel -> curve finished
                return array if (x0 == x2 && y0 == y2)
                # save value for test of y step
                y1 = 2*err < dx
                # x step
                if (2*err > dy)
                    x0 += sx
                    dx -= xy
                    err += dy += yy
                end
                # y step
                if y1
                    y0 += sy
                    dy -= xy
                    err += dx += xx
                end
                array.push({x: x0, y: y0})
            end while (dy < 0 && dx > 0)
        end
        # plot remaining part to end
        rest = self.line(x0,y0, x2,y2)
        array += rest
        array
    end
    
    # plot any quadratic Bezier curve
    def self.quadBezier (x0, y0, x1, y1, x2, y2)
        array = []
      
        x = x0-x1
        y = y0-y1
        t = (x0-2*x1+x2).to_f
        
        # horizontal cut at P4?
        if (x*(x2-x1) > 0)
          # vertical cut at P6 too?
          if (y*(y2-y1) > 0)
            # which first?
            if (((y0-2*y1+y2)/t*x).abs > y.abs)
              # swap points
              x0 = x2
              x2 = x+x1
              y0 = y2
              y2 = y+y1
              # now horizontal cut at P4 comes first
            end
          end
          t = (x0-x1)/t
          # By(t=P4)
          r = (1-t)*((1-t)*y0+2.0*t*y1)+t*t*y2
          # gradient dP4/dx=0
          t = (x0*x2-x1*x1)*t/(x0-x1)
          x = (t+0.5).floor
          y = (r+0.5).floor
          # intersect P3 | P0 P1
          r = (y1-y0)*(t-x0)/(x1-x0)+y0
          seg = self.quadBezierSeg(x0,y0, x,(r+0.5).floor, x,y)
          array += seg
          r = (y1-y2)*(t-x2)/(x1-x2)+y2
          x0 = x1 = x
          y0 = y
          y1 = (r+0.5).floor
        end
        
        # vertical cut at P6?
        if ((y0-y1)*(y2-y1) > 0)
          t = (y0-2*y1+y2).to_f
          t = (y0-y1)/t
          # Bx(t=P6)
          r = (1-t)*((1-t)*x0+2.0*t*x1)+t*t*x2
          # gradient dP6/dy=0
          t = (y0*y2-y1*y1)*t/(y0-y1)
          x = (r+0.5).floor
          y = (t+0.5).floor
          # intersect P6 | P0 P1
          r = (x1-x0)*(t-y0)/(y1-y0)+x0
          seg = self.quadBezierSeg(x0, y0, (r+0.5).floor, y, x, y)
          array += seg
          # intersect P7 | P1 P2
          r = (x1-x2)*(t-y2)/(y1-y2)+x2
          # P0 = P6, P1 = P7
          x0 = x
          x1 = (r+0.5).floor
          y0 = y1 = y
        end
        # remaining part
        seg = self.quadBezierSeg(x0,y0, x1,y1, x2,y2)
        array += seg
        array
    end

    def self.cubicBezierSeg(x0, y0, x1, y1, x2, y2, x3, y3)
        array = []
        swapped = false
        
        ax = x0
        ay = y0
        
        leg = 2
        
        #  step direction
        sx = x0 < x3 ? 1 : -1
        sy = y0 < y3 ? 1 : -1
        xc = -1 * (x0+x1-x2-x3).abs
        xa = xc-4*sx*(x1-x2)
        xb = sx*(x0-x1-x2+x3)
        yc = -1 * (y0+y1-y2-y3).abs
        ya = yc-4*sy*(y1-y2)
        yb = sy*(y0-y1-y2+y3)
        # check for curve restrains
        # slope P0-P1 == P2-P3    and  (P0-P3 == P1-P2      or  no slope change)
        self.assert((x1-x0)*(x2-x3) < EP && ((x3-x0)*(x1-x2) < EP || xb*xb < xa*xc+EP))
        self.assert((y1-y0)*(y2-y3) < EP && ((y3-y0)*(y1-y2) < EP || yb*yb < ya*yc+EP))
        # quadratic Bezier
        return self.quadBezierSeg(x0,y0, (3*x1-x0).to_i>>1,(3*y1-y0).to_i>>1, x3,y3) if (xa == 0 && ya == 0)
        # line lengths
        x1 = (x1-x0)*(x1-x0)+(y1-y0)*(y1-y0)+1
        x2 = (x2-x3)*(x2-x3)+(y2-y3)*(y2-y3)+1
        # loop over both ends
        begin
          a = []
          
          ab = xa*yb-xb*ya
          ac = xa*yc-xc*ya
          bc = xb*yc-xc*yb
          # P0 part of self-intersection loop?
          ex = ab*(ab+ac-3*bc)+ac*ac
          # calc resolution
          f = ex > 0 ? 1 : (Math.sqrt(1+1024/x1)).floor
          # increase resolution
          ab *= f
          ac *= f
          bc *= f
          ex *= f*f
          # init differences of 1st degree
          xy = 9*(ab+ac+bc)/8
          cb = 8*(xa-ya)
          dx = 27*(8*ab*(yb*yb-ya*yc)+ex*(ya+2*yb+yc))/64-ya*ya*(xy-ya)
          dy = 27*(8*ab*(xb*xb-xa*xc)-ex*(xa+2*xb+xc))/64-xa*xa*(xy+xa)
          # init differences of 2nd degree
          xx = 3*(3*ab*(3*yb*yb-ya*ya-2*ya*yc)-ya*(3*ac*(ya+yb)+ya*cb))/4
          yy = 3*(3*ab*(3*xb*xb-xa*xa-2*xa*xc)-xa*(3*ac*(xa+xb)+xa*cb))/4
          xy = xa*ya*(6*ab+6*ac-3*bc+cb)
          ac = ya*ya
          cb = xa*xa
          xy = 3*(xy+9*f*(cb*yb*yc-xb*xc*ac)-18*xb*yb*ab)/8
          # negate values if inside self-intersection loop
          if (ex < 0)
              dx = -dx
              dy = -dy
              xx = -xx
              yy = -yy
              xy = -xy
              ac = -ac
              cb = -cb
          end
        # init differences of 3rd degree
        ab = 6*ya*ac
        ac = -6*xa*ac
        bc = 6*ya*cb
        cb = -6*xa*cb
        # error of 1st step
        dx += xy
        ex = dx+dy
        dy += xy
        catch :exit do
          pxy = 0
          fx = fy = f
          while (x0 != x3 && y0 != y3)            
            begin
              # confusing values
              throw :exit if (pxy == 0) if (dx > xy || dy < xy)
              throw :exit if (pxy == 1) if (dx > 0 || dy < 0)
              # save value for test of y step
              y1 = 2*ex-dy
              # x sub-step
              if (2*ex >= dx)
                fx-=1
                ex += dx += xx
                dy += xy += ac
                yy += bc
                xx += ab
              elsif (y1 > 0) 
                  throw :exit 
              end
              # y sub-step
              if (y1 <= 0)
                fy-=1
                ex += dy += yy
                dx += xy += bc
                xx += ac
                yy += cb
              end
              # pixel complete?
            end while  (fx > 0 && fy > 0)
            # puts "cubic x#{x0} y#{y0}"
            # x step
            if (2*fx <= f)
              x0 += sx
              fx += f  
            end
            # y step
            if (2*fy <= f)              
              y0 += sy
              fy += f  
            end
            a.push({x: x0, y: y0})
            pxy = 1 if (pxy == 0 && dx < 0 && dy > 0)
          end
        end
        # swap legs
        xx = x0
        ax =x0 = x3
        x3 = xx
        sx = -sx
        xb = -xb
        yy = y0
        ay = y0 = y3
        y3 = yy
        sy = -sy
        yb = -yb
        x1 = x2
        
        leg-=1
        
        a.reverse! if swapped
        array += a
        
        swapped = true
      end while (leg != 0)
      rest = self.line(x0,y0, x3,y3)
      
      array = array + rest
    end
    # plot any cubic Bezier curve
    def self.cubicBezier(x0, y0, x1, y1, x2, y2, x3, y3)
      array = []
      n = 0
      xc = x0+x1-x2-x3
      xa = xc-4.0*(x1-x2)
      xb = x0-x1-x2+x3
      xd = xb+4.0*(x1+x2)
      yc = y0+y1-y2-y3
      ya = yc-4.0*(y1-y2)
      yb = y0-y1-y2+y3
      yd = yb+4.0*(y1+y2)
      fx0 = x0
      fy0 = y0
      t1 = xb*xb-xa*xc
      t = []
      # sub-divide curve at gradient sign changes
      # horizontal
      if (xa == 0)
          # one change
          if (xc.abs < 2*xb.abs)
            t.push(xc/(2.0*xb))
            n+=1
          end
      elsif (t1 > 0.0)
          # two changes
          t2 = Math.sqrt(t1)
          t1 = (xb-t2)/xa
          if (t1.abs < 1.0)
            t.push(t1)
            n+=1
          end
          t1 = (xb+t2)/xa
          if (t1.abs < 1.0)
            t.push(t1)
            n+=1
          end
      end
      t1 = yb*yb-ya*yc
      # vertical
      if (ya == 0)
          # one change
          if (yc.abs < 2*yb.abs)
            t.push(yc/(2.0*yb))
            n+=1
          end
      elsif (t1 > 0.0)
          # two changes
          t2 = Math.sqrt(t1)
          t1 = (yb-t2)/ya
          if (t1.abs < 1.0) 
            t.push(t1)
            n+=1
          end
          t1 = (yb+t2)/ya
          if (t1.abs < 1.0)
            t.push(t1)
            n+=1
          end
      end
      # bubble sort of 4 points
      i = 0
      while i < n do
          t1 = t[i-1]
          if (t1 > t[i])
              t[i-1] = t[i]
              t[i] = t1
              i = 0
          end
          i+=1  
      end
      # begin / end point
      t1 = -1.0
      t[n] = 1.0
      # plot each segment separately
      for i in 0..n do
          # sub-divide at t[i-1], t[i]
          t2 = t[i]
          fx1 = (t1*(t1*xb-2*xc)-t2*(t1*(t1*xa-2*xb)+xc)+xd)/8-fx0
          fy1 = (t1*(t1*yb-2*yc)-t2*(t1*(t1*ya-2*yb)+yc)+yd)/8-fy0
          fx2 = (t2*(t2*xb-2*xc)-t1*(t2*(t2*xa-2*xb)+xc)+xd)/8-fx0
          fy2 = (t2*(t2*yb-2*yc)-t1*(t2*(t2*ya-2*yb)+yc)+yd)/8-fy0
          fx0 -= fx3 = (t2*(t2*(3*xb-t2*xa)-3*xc)+xd)/8
          fy0 -= fy3 = (t2*(t2*(3*yb-t2*ya)-3*yc)+yd)/8
          # scale bounds
          x3 = (fx3+0.5).floor
          y3 = (fy3+0.5).floor
          if (fx0 != 0.0)
              fx1 *= fx0 = (x0-x3)/fx0
              fx2 *= fx0
          end
          if (fy0 != 0.0)
              fy1 *= fy0 = (y0-y3)/fy0
              fy2 *= fy0
          end
          # segment t1 - t2
          if (x0 != x3 || y0 != y3)
            seg = self.cubicBezierSeg(x0,y0, x0+fx1,y0+fy1, x0+fx2,y0+fy2, x3,y3)
            array += seg
          end
          x0 = x3
          y0 = y3
          fx0 = fx3
          fy0 = fy3
          t1 = t2
      end
      array
    end
end
