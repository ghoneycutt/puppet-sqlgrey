# Class: sqlgrey
#
# This module manages sqlgrey - http://sqlgrey.sourceforge.net/
#
# Requires:
#   class mysql::server
#   class postfix
#   $sqlgreyAdminMail be set in site manifest
#
class sqlgrey {

    include mysql::server
    include postfix

    package { "sqlgrey": }

    file {
        "/var/log/maillog":
            group   => sqlgrey,
            require => Package["sqlgrey"],
            mode    => 640;
        "/etc/sqlgrey/sqlgrey.conf":
            content => template("sqlgrey/sqlgrey.conf.erb"),
            require => Package["sqlgrey"],
            notify  => Service["sqlgrey"];
        # You don't need to restart sqlgrey as it monitors the ".local" files
        # and reload them as soon as they change or when they are created for
        # the first time.
        "/etc/sqlgrey/clients_fqdn_whitelist.local":
            source  => "puppet:///modules/sqlgrey/clients_fqdn_whitelist.local",
            require => Package["sqlgrey"];
        "/etc/sqlgrey/clients_ip_whitelist.local":
            source  => "puppet:///modules/sqlgrey/clients_ip_whitelist.local",
            require => Package["sqlgrey"];
        "/usr/local/sbin/sqlgrey-logstats-cron.sh":
            content => template("sqlgrey/sqlgrey-logstats.cron.erb"),
            require => Package["sqlgrey"],
            mode    => 754,
            group   => sqlgrey;
    } # file

    # setup database 
    mysql::do {
        "sqlgrey_db_create":
            source  => "puppet:///modules/sqlgrey/setup_db.sql";
    } # mysql::do

    service { "sqlgrey":
        enable  => true,
        ensure  => running,
        require => [ Package["sqlgrey"], Mysql::Do["sqlgrey_db_create"] ],
    } # service

    # needed for sqlgrey-logstats to work
    pam::accesslogin { "sqlgrey": }

    cron {
        "update_sqlgrey_config":
            command     => "/usr/sbin/update_sqlgrey_config",
            user        => sqlgrey,
            hour        => 7,
            minute      => 0,
            require     => Package["sqlgrey"];
        "sqlgrey-logstats":
            command     => "/usr/local/sbin/sqlgrey-logstats-cron.sh",
            require     => [ Package["sqlgrey"], File["/usr/local/sbin/sqlgrey-logstats-cron.sh"], ],
            user        => sqlgrey,
            hour        => 0,
            minute      => 0,
            weekday     => Monday,
            environment => "MAILTO=$sqlgreyAdminMail";
    } # cron

} # class sqlgrey
