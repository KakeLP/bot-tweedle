#!/usr/bin/env perl
package Tweedle;
our $VERSION = '0.0.1';
use Moses;

with qw(
  MooseX::Getopt
  MooseX::Workers
);

#
# PUBLIC ATTRIBUTES
#

channels '#openguides';

has username => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
    default  => sub { 'openguides' },
);

has password => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
    default  => sub { 'CHANGEME' },
);

has users => (
    isa        => 'ArrayRef',
    is         => 'ro',
    auto_deref => 1,
    default    => sub {
        [
            qw(
              perigrin
              bob
              ilmari
              ivorw
              jimbo
              justn
              knewt
              Socks
              Kake
              Dom
              hex
              )
        ];
    },
);

#
# PRIVATE ATTRIBUTES
#

has _twitter => (
    isa      => 'Net::Twitter',
    lazy     => 1,
    accessor => 'twitter',
    default  => sub {
        require Net::Twitter;
        Net::Twitter->new(
            username => $_[0]->username,
            password => $_[0]->password,
        );
    },
    handles => { update_twitter => 'update', }
);

sub help() {
    return <<"END";
I'm a twitter bot, I post as ${ \$_[0]->username } on twitter. Use tweet: \$msg to post.
END
}

sub verify_nick {
    my ( $self, $nick ) = @_;
    return 1 if grep { /\Q$nick\E/i } $self->users;
    return 0;
}

sub send_tweet {
    my ( $self, $nick, $msg ) = @_;
    $self->run_command(
        sub {
            require HTML::Entities;
            my $ret = $self->update_twitter(
                "[$nick] $msg") # <> seems to cause issues with motorolla phones
              || { text => 'nothing posted, something went wrong' };
            print "$nick|" . decode_entities( $ret->{text} );
        }
    );
}

my $TOO_LONG_MSG =
  'The tweet is too long, please make it less than 140 characters';

my $NO_PERM_MSG = "you don't seem to have permission to tweet";

sub tweet {
    my ( $self, $nick, $msg ) = @_;
    unless ( $self->verify_nick($nick) ) {
        $self->privmsg( $nick => "$nick: $NO_PERM_MSG" );
        return;
    }
    if ( length $msg > 140 ) {
        $self->privmsg( $nick => $TOO_LONG_MSG );
        return;
    }
    $self->send_tweet( $nick, $msg );
    $self->privmsg( $nick => "$nick: post queued" );
}

event irc_public => sub {
    my ( $self, $sender, $who, $where, $what ) =
      @_[ OBJECT, SENDER, ARG0, ARG1, ARG2 ];
    my $nick    = ( split /!/, $who )[0];
    my $channel = $where->[0];
    my $botnick = $self->nickname;

    if ( my ($msg) = $what =~ /^(?:tweet|twitter)[:,]?\s+(.+)/i ) {
        $self->tweet( $nick => $msg );
        return;
    }
    return;
};

event irc_bot_addressed => sub {
    my ( $self, $sender, $who, $where, $what ) =
      @_[ OBJECT, SENDER, ARG0, ARG1, ARG2 ];
    my $nick    = ( split /!/, $who )[0];
    my $channel = $where->[0];
    my $botnick = $self->nickname;

    if ( $what =~ /^\s*help\s*$/i ) {
        $self->privmsg( $nick => $self->help );
        return;
    }
    $self->tweet( $nick => $what );
    return;

};

event irc_msg => sub {
    $_[ARG2] = join ' ', $_[0]->nickname, $_[ARG2];
    ( shift->can('irc_bot_addressed') )->(@_);
};

event worker_stdout => sub {
    my ( $self, $input ) = @_;
    my ( $nick, $msg ) = split /\|/, $input;
    $self->privmsg( $nick => qq(posted "$msg") );
};

__PACKAGE__->run unless caller;

no Moose;
1;    # Magic true value required at end of module
__END__
