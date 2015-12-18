#!/usr/bin/env ruby

require 'open3'


  def _lsblk
    lsblk = {
      # kname => {}
    }

    stdin, stdout, stderr = Open3.popen3(%q{lsblk -Pbo 'NAME,KNAME,MAJ:MIN,RM,SIZE,TYPE,MODEL'})
    stdout.each_line { |line|
      h = {}
      line.scan(/([^\s=]+)="([^"]*)"/).each { |k, v|
        h[k] = v
      }
      lsblk[h['KNAME']] = h
    }

    lsblk
  end

  def _multipath
    multipath = {
      :devs => {
        # dev => uuid
      },
      :maps => {
        # uuid => name
      },
    }

    stdin, stdout, stderr = Open3.popen3(%q{multipathd -k'list maps format "%n;;%w"'})
    stdout.each_line.with_index { |line, lineno|
      next if lineno == 0
      n, w = line.split(';;').map(&:strip)
      multipath[:maps][w] = n
    }

    stdin, stdout, stderr = Open3.popen3(%q{multipathd -k'list paths format "%d;;%w"'})
    stdout.each_line.with_index { |line, lineno|
      next if lineno == 0
      d, w = line.split(';;').map(&:strip)
      multipath[:devs][d] = w if multipath[:maps][w]
    }

    multipath
  end

  def _udev_symlink(kname)
    stdin, stdout, stderr = Open3.popen3("udevadm info --query=symlink --name=#{kname}")
    stdout.read.split(' ')
  end

##############################################################
        detailed_meta = {:disks => []}

        lsblk = _lsblk()
        multipath = _multipath()

        lsblk.each { |kname, h|
          disk = h['KNAME']
          name = h['NAME']
          case h['TYPE']
            when 'disk'
              next if multipath[:devs][h['KNAME']]
            when 'mpath'
              disk = "mapper/#{h['NAME']}"
              name = "mapper/#{h['NAME']}"
            else
              next
          end

          detailed_meta[:disks] << {
            :disk => disk,
            :extra => _udev_symlink(h['KNAME']),
            :model => h['MODEL'],
            :name => name,
            :removable => h['RM'],
            :size => h['SIZE'].to_i,
          }
        }


puts "_lsblk: #{lsblk.inspect}"
puts "_multipath: #{multipath.inspect}"
puts "disks: #{detailed_meta[:disks].inspect}"
