#!/usr/bin/env ruby
#--
# Yast Webservice framework
#
# Copyright (C) 2009, 2010 Novell, Inc. 
#   This library is free software; you can redistribute it and/or modify
# it only under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation. 
#
#   This library is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more 
# details. 
#
#   You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software 
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#++


require 'rubygems'
require 'dbus'
require 'etc'
require 'polkit'

# Choose the bus (could also be DBus::session_bus, which is not suitable for a system service)
bus = DBus::system_bus
# Define the service name
service = bus.request_service("yast.permissions.service")

class YastPermissionsService < DBus::Object

  # overriding DBus::Object#dispatch
  # It is needed because dispatch sent just parameters and without sender it is
  # imposible to check permissions of sender. So to avoid it add as last
  # parameter sender id.
  def dispatch(msg)
    msg.params << msg.sender
    super(msg)
  end

  def log(msg)
    f = File.new("/tmp/yast_permission_service.log","a",0600)
    f.write(msg+"\n")
    f.close
  end

  # Create an interface.
  dbus_interface "yast.permissions.Interface" do
    dbus_method :grant, "out result:as, in permissions:as, in user:s" do |permissions,user,sender|
      result = execute("grant", permissions, user,sender)
      log "Grant permissions #{permissions.inspect} for user #{user} with result #{result.inspect}"
      [result]
    end
    dbus_method :revoke, "out result:as, in permissions:as, in user:s" do |permissions,user,sender|
      result = execute("revoke", permissions, user,sender)
      log "Revoke permissions #{permissions.inspect} for user #{user} with result #{result.inspect}"
      [result]
    end
  end

USER_REGEX=/\A[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_][ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$-]?\Z/
USER_WITH_DOMAIN_REGEX=/\A[a-zA-Z0-9][a-zA-Z0-9\-.]*\\[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_][ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$-]?\Z/
  def execute (command, permissions, user, sender)
    #TODO polkit check, user escaping, perm whitespacing
    return ["NOPERM"] unless check_polkit sender
    return ["USER_INVALID"] if invalid_user_name? user 
    result = []
    permissions.each do |p|
      #whitespace check for valid permission string to avoid attack
      if p.match(/^[a-zA-Z][a-zA-Z0-9.-]*$/)
        result << `polkit-auth --user '#{user}' --#{command} '#{p}' 2>&1` # RORSCAN_ITL
      else
        result << "perm #{p} is INVALID" # XXX tom: better don't include invalif perms here, we do not know what the calling function is doing with it, like displaying it via the browser, passing it to the shell etc.
      end
    end
    return result
  end

  PERMISSION="org.opensuse.yast.permissions.read"
  def check_polkit(sender)
    uid = DBus::SystemBus.instance.proxy.GetConnectionUnixUser(sender)[0]
    user = Etc.getpwuid(uid).name
    begin
      return PolKit.polkit_check(PERMISSION, user) == :yes
    rescue Exception => e
      return false
    end
  end

  def invalid_user_name? user
    active_directory_enabled = `/usr/sbin/pam-config -q --winbind 2>/dev/null | wc -w`.to_i > 0 # RORSCAN_ITL
    return false if user.match(USER_REGEX)
    return false if active_directory_enabled && user.match(USER_WITH_DOMAIN_REGEX)
    return true
  end
end

# Set the object path
obj = YastPermissionsService.new("/yast/permissions/Interface")
# Export it!
service.export(obj)

# Now listen to incoming requests
main = DBus::Main.new
main << bus
main.run
