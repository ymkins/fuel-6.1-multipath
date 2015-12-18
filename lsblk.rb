#!/usr/bin/env ruby

require 'open3'


  def _lsblk(cmdline=nil)
    cmdline ||= "lsblk -Pbo 'NAME,KNAME,MAJ:MIN,RM,SIZE,TYPE,MODEL'"
    lsblk = {
      # kname => {}
    }

    stdin, stdout, stderr = Open3.popen3(cmdline)
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
      :maps_by_name => {
        # name => uuid
      },
    }

    stdin, stdout, stderr = Open3.popen3(%q{multipathd -k'list maps format "%n;;%w"'})
    stdout.each_line.with_index { |line, lineno|
      next if lineno == 0
      n, w = line.split(';;').map(&:strip)
      multipath[:maps][w] = n
      multipath[:maps_by_name][n] = w
    }

    stdin, stdout, stderr = Open3.popen3(%q{multipathd -k'list paths format "%d;;%w"'})
    stdout.each_line.with_index { |line, lineno|
      next if lineno == 0
      d, w = line.split(';;').map(&:strip)
      multipath[:devs][d] = w if multipath[:maps][w]
    }

    multipath
  end

  def _udev_property(kname)
    h = {}
    stdin, stdout, stderr = Open3.popen3("udevadm info --query=property --name=#{kname}")
    stdout.each_line { |line|
      k, v = line.split('=', 2).map(&:strip)
      h[k] = v
    }
    h
  end

  def _udev_symlink(kname)
    stdin, stdout, stderr = Open3.popen3("udevadm info --query=symlink --name=#{kname}")
    stdout.read.split(' ')
  end

##############################################################
def q1
        detailed_meta = {:disks => []}

        ## Stop multipathd to prevent dm-devices from installer 
        # system "service multipathd stop; sleep 1; multipath -F; sleep 1; service multipathd start; sleep 1"
        disks = _lsblk()
        multipath = _multipath()
        # system "service multipathd stop; sleep 1; multipath -F"

        disks.each { |kname, h|
          disk = h['KNAME']
          name = h['NAME']
          case h['TYPE']
            when 'disk'
              next if multipath[:devs][h['KNAME']]
            when 'mpath'
              disk = "disk/by-id/dm-uuid-mpath-#{multipath[:maps_by_name][h['NAME']]}"
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


  printf("\n#q1\n")
  printf("\n#lsblk:\n%s\n", disks.inspect)
  printf("\n#multipath:\n%s\n", multipath.inspect)
  printf("\n#disks:\n%s\n", detailed_meta[:disks].inspect)
end

##############################################################
def q2
        detailed_meta = {:disks => []}

        disks = _lsblk("lsblk -Pdbo 'NAME,KNAME,MAJ:MIN,RM,SIZE,TYPE,MODEL'")
        serials = {
          # serial => [knames]
        }

        disks.each { |kname, h|
          udev = _udev_property(h['KNAME'])
          h['DEVLINKS'] = udev.fetch('DEVLINKS', '')
          h['DEVPATH'] = udev.fetch('DEVPATH', '')
          h['ID_SERIAL'] = udev.fetch('ID_SERIAL', '')
          serials[h['ID_SERIAL']] = (serials[h['ID_SERIAL']] || []).push(h['KNAME'])
        }

        # filter out the multipath devices
        serials.each { |id, knames|
          if id && knames.length > 1
            knames.each { |kname|
              disks.delete(kname)
            }
          end
        }

        disks.each { |kname, h|
          detailed_meta[:disks] << {
            :disk => h['DEVPATH'],
            :extra => h['DEVLINKS'].split(' '),
            :model => h['MODEL'],
            :name => h['NAME'],
            :removable => h['RM'],
            :size => h['SIZE'].to_i,
          }
        }


  printf("\n#q2\n")
  printf("\n#lsblk:\n%s\n", _lsblk().inspect)
  printf("\n#serials:\n%s\n", serials.inspect)
  printf("\n#disks:\n%s\n", detailed_meta[:disks].inspect)
end

##############################################################
q1()
q2()

