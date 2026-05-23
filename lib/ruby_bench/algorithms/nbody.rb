# typed: true
# frozen_string_literal: true

module RubyBench
  module Algorithms
    module Nbody
      PI = Math::PI
      SOLAR_MASS = 4.0 * PI * PI
      DAYS_PER_YEAR = 365.24

      Body = Struct.new(:x, :y, :z, :vx, :vy, :vz, :mass)

      # run 太陽系5天体を steps 回 0.01 単位時刻で進め、初期と最終のエネルギーを返します。
      def self.run(steps)
        bodies = solar_bodies
        offset_momentum(bodies)
        initial = energy(bodies)
        steps.times { advance(bodies, 0.01) }
        final = energy(bodies)
        { initial_energy: initial, final_energy: final }
      end

      # solar_bodies 太陽とジョビアン惑星4天体の初期状態の Body 配列を返します。
      def self.solar_bodies
        [
          Body.new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, SOLAR_MASS),
          Body.new(
            4.84143144246472090e+00,
            -1.16032004402742839e+00,
            -1.03622044471123109e-01,
            1.66007664274403694e-03 * DAYS_PER_YEAR,
            7.69901118419740425e-03 * DAYS_PER_YEAR,
            -6.90460016972063023e-05 * DAYS_PER_YEAR,
            9.54791938424326609e-04 * SOLAR_MASS
          ),
          Body.new(
            8.34336671824457987e+00,
            4.12479856412430479e+00,
            -4.03523417114321381e-01,
            -2.76742510726862411e-03 * DAYS_PER_YEAR,
            4.99852801234917238e-03 * DAYS_PER_YEAR,
            2.30417297573763929e-05 * DAYS_PER_YEAR,
            2.85885980666130812e-04 * SOLAR_MASS
          ),
          Body.new(
            1.28943695621391310e+01,
            -1.51111514016986312e+01,
            -2.23307578892655734e-01,
            2.96460137564761618e-03 * DAYS_PER_YEAR,
            2.37847173959480950e-03 * DAYS_PER_YEAR,
            -2.96589568540237556e-05 * DAYS_PER_YEAR,
            4.36624404335156298e-05 * SOLAR_MASS
          ),
          Body.new(
            1.53796971148509165e+01,
            -2.59193146099879641e+01,
            1.79258772950371181e-01,
            2.68067772490389322e-03 * DAYS_PER_YEAR,
            1.62824170038242295e-03 * DAYS_PER_YEAR,
            -9.51592254519715870e-05 * DAYS_PER_YEAR,
            5.15138902046611451e-05 * SOLAR_MASS
          )
        ]
      end

      # offset_momentum 太陽を運動量で補正します。
      def self.offset_momentum(bodies)
        px = 0.0
        py = 0.0
        pz = 0.0
        bodies.each do |b|
          px += b.vx * b.mass
          py += b.vy * b.mass
          pz += b.vz * b.mass
        end
        sun = bodies[0]
        sun.vx = -px / SOLAR_MASS
        sun.vy = -py / SOLAR_MASS
        sun.vz = -pz / SOLAR_MASS
      end

      # advance 1ステップ dt だけ全天体を進めます。
      def self.advance(bodies, dt)
        n = bodies.size
        i = 0
        while i < n
          bi = bodies[i]
          j = i + 1
          while j < n
            bj = bodies[j]
            dx = bi.x - bj.x
            dy = bi.y - bj.y
            dz = bi.z - bj.z
            d2 = (dx * dx) + (dy * dy) + (dz * dz)
            mag = dt / (d2 * Math.sqrt(d2))
            bi.vx -= dx * bj.mass * mag
            bi.vy -= dy * bj.mass * mag
            bi.vz -= dz * bj.mass * mag
            bj.vx += dx * bi.mass * mag
            bj.vy += dy * bi.mass * mag
            bj.vz += dz * bi.mass * mag
            j += 1
          end
          i += 1
        end
        bodies.each do |b|
          b.x += dt * b.vx
          b.y += dt * b.vy
          b.z += dt * b.vz
        end
      end

      # energy 系全体の力学エネルギーを返します。
      def self.energy(bodies)
        e = 0.0
        n = bodies.size
        i = 0
        while i < n
          bi = bodies[i]
          e += 0.5 * bi.mass * ((bi.vx * bi.vx) + (bi.vy * bi.vy) + (bi.vz * bi.vz))
          j = i + 1
          while j < n
            bj = bodies[j]
            dx = bi.x - bj.x
            dy = bi.y - bj.y
            dz = bi.z - bj.z
            d = Math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
            e -= (bi.mass * bj.mass) / d
            j += 1
          end
          i += 1
        end
        e
      end
    end
  end
end
