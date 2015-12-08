package AzeOP;

use Mojo::Base 'CallBackery';

=head1 NAME

AzeOP - the application class

=head1 SYNOPSIS

 use Mojolicious::Commands;
 Mojolicious::Commands->start_app('AzeOP');

=head1 DESCRIPTION

Configure the mojolicious engine to run our application logic

=cut

=head1 ATTRIBUTES

AzeOP has all the attributes of L<CallBackery> plus:

=cut

=head2 config

use our own plugin directory and our own configuration file:

=cut

has config => sub {
    my $self = shift;
    my $config = $self->SUPER::config(@_);
    $config->file($ENV{AzeOP_CONFIG} || $self->home->rel_file('etc/aze_op.cfg'));
    unshift @{$config->pluginPath}, 'AzeOP::GuiPlugin';
    return $config;
};

has database => sub {
    my $self = shift;
    my $database = $self->SUPER::database(@_);
    $database->sql->migrations
        ->name('AzeOPBaseDB')
        ->from_data(__PACKAGE__,'appdb.sql')
        ->migrate;
    return $database;
};

1;

=head1 COPYRIGHT

Copyright (c) 2015 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=cut

__DATA__

@@ appdb.sql

-- 1 up

-- time tracking (arbeits zeit erfassung)
CREATE TABLE aze (
    aze_id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    aze_cbuser      INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    aze_start       DATETIME NOT NULL,
    aze_duration    INTEGER, -- seconds
    aze_note        TEXT,
    aze_lastmod     TEXT NOT NULL
);

-- absence tracking (ferien / krankheit)
CREATE TABLE abs (
    abs_id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    abs_cbuser      INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    abs_start       DATE NOT NULL,
    abs_duration    INEGER NOT NULL, -- days
    abs_note        TEXT
    abs_lastmod     TEXT NOT NULL
);

-- public holidays (oeffentliche feiertage)
CREATE TABLE pho (
    pho_id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    pho_date        DATE NOT NULL,
    pho_title       TEXT NOT NULL,
    pho_lastmod     TEXT NOT NULL
);

-- employment status (anstellungsgrad)
CREATE TABLE ems (
    ems_id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    ems_cbuser      INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    ems_start       DATE NOT NULL,
    ems_percent     INTEGER NOT NULL,
    ems_note        TEXT,
    ems_lastmod     TEXT NOT NULL
);

-- add an extra right for people who can edit

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES ('record','Arbeitszeit Erfassen');

-- 1 down

DROP TABLE aze;
DROP TABLE abs;
DROP TABLE pho;
DROP TABLE ems;
