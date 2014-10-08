package WWW::PushBullet;

=head1 NAME

WWW::PushBullet - Module giving easy access to PushBullet API

=head1 DESCRIPTION

Module giving easy access to PushBullet API

=head1 SYNOPSIS

    use WWW::PushBullet;
    
    my $pb = WWW::PushBullet->new({apikey => $apikey});
    
    $pb->push_address({ device_iden => $device_iden, name => $name, 
        address => $address });
        
    $pb->push_file({ device_iden => $device_iden, file => $filename);
        
    $pb->push_link({ device_iden => $device_iden, title => $title,
        url => $url });
        
    $pb->push_list({ device_iden => $device_iden, title => $title, 
        items => \@items });
        
    $pb->push_note({ device_iden => $device_iden, title => $title,
        body => $body });

=cut

use strict;
use warnings;

use Data::Dump qw(dump);
use JSON;
use LWP::UserAgent;

our $VERSION = '1.2.2';

my %PUSHBULLET = (
    REALM     => 'Pushbullet',
    SERVER    => 'api.pushbullet.com:443',
    URL_APIV2 => 'https://api.pushbullet.com/v2',
);

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

=head1 SUBROUTINES/METHODS

=head2 new($params)

Creates a new instance of PushBullet API

    my $pb = WWW::PushBullet->new({apikey => $apikey});

=cut

sub new
{
    my ($class, $params) = @_;

    return (undef) if (!defined $params->{apikey});
    my $ua = LWP::UserAgent->new;
    $ua->agent("WWW::PushBullet/$VERSION");
    $ua->proxy('https', $params->{proxy}) if (defined $params->{proxy});
    $ua->credentials($PUSHBULLET{SERVER}, $PUSHBULLET{REALM},
        $params->{apikey}, '');

    my $self = {
        _ua     => $ua,
        _apikey => $params->{apikey},
        _debug  => $params->{debug} || 0,
    };

    bless $self, $class;

    return ($self);
}

=head2 DEBUG

Prints Debug message when '_debug' is enabled

=cut

sub DEBUG
{
    my ($self, $line) = @_;

    if ($self->{_debug})
    {
        my $str = sprintf '[DEBUG] %s', $line;
        printf "$str\n";

        return ($str);
    }

    return (undef);
}

=head2 api_key()

Returns current PushBullet API key

    my $apikey = $pb->api_key();

=cut

sub api_key
{
    my $self = shift;

    return ($self->{_apikey});
}

=head2 debug_mode

Sets Debug mode

    $pb->debug_mode(1);

=cut

sub debug_mode
{
    my ($self, $mode) = @_;

    $self->{_debug} = $mode;

    return ($self->{_debug});
}

=head2 contacts()

Returns list of contacts

    my $contacts = $pb->contacts();
    
    foreach my $c (@{$contacts})
    {
        printf "Contact '%s' (%s) => %s\n", $c->{name}, $c->{iden}, $c->{email};
    }

=cut

sub contacts
{
    my $self = shift;

    my $res = $self->{_ua}->get("$PUSHBULLET{URL_APIV2}/contacts");

    if ($res->is_success)
    {
        my $data = JSON->new->decode($res->content);
        return ($data->{contacts});
    }
    else
    {
        print $res->status_line, "\n";
        return (undef);
    }
}

=head2 devices()
    
Returns list of devices

    my $devices = $pb->devices();
    
    foreach my $d (@{$devices})
    {
        printf "Device '%s' (%s)=> id %s\n", 
            $d->{nickname}, $d->{model}, $d->{iden};
    }

=cut

sub devices
{
    my $self = shift;

    my $res = $self->{_ua}->get("$PUSHBULLET{URL_APIV2}/devices");

    if ($res->is_success)
    {
        my $data = JSON->new->decode($res->content);
        return ($data->{devices});
    }
    else
    {
        print $res->status_line, "\n";
        return (undef);
    }
}

=head2 _pushes($content)

Generic pushes function (not supposed to be used directly)

=cut

sub _pushes
{
    my ($self, $content) = @_;

    my $type = undef;
    foreach my $i (0 .. $#{$content})
    {
        $type = $content->[$i + 1] if ($content->[$i] eq 'type');
    }
    my $res = $self->{_ua}->post(
        "$PUSHBULLET{URL_APIV2}/pushes",
        Content_Type => ($type eq 'file' ? 'form-data' : undef),
        Content => $content
    );

    if ($res->is_success)
    {
        my $data = JSON->new->decode($res->content);
        return ($data);
    }
    else
    {
        print $res->status_line, "\n";
        return (undef);
    }
}

=head2 push_address($params)

Pushes address (with name & address)

    $pb->push_address(
        {
            device_iden => $device_iden,
            name        => 'GooglePlex',
            address     => '1600 Amphitheatre Pkwy, Mountain View, CA 94043, Etats-Unis'
        }
        );

=cut

sub push_address
{
    my ($self, $params) = @_;

    my $content = [
        type        => 'address',
        device_iden => $params->{device_iden},
        name        => $params->{name},
        address     => $params->{address},
    ];
    $self->DEBUG(sprintf('push_address: %s', dump($content)));
    my $result = $self->_pushes($content);

    return ($result);
}

=head2 push_file($params)

Pushes file

    $pb->push_file({ device_iden => $device_iden, file => '/var/www/index.html' });

=cut

sub push_file
{
    my ($self, $params) = @_;

    my $content = [
        type        => 'file',
        device_iden => $params->{device_iden},
        file        => [$params->{file}],
    ];
    $self->DEBUG(sprintf('push_file: %s', dump($content)));
    my $result = $self->_pushes($content);

    return ($result);
}

=head2 push_link($params)

Pushes link (with title & url)

    $pb->push_link(
        {
            device_iden => $device_iden,
            title       => 'WWW::PushBullet Perl module on GitHub',
            url         => 'https://github.com/sebthebert/WWW-PushBullet'
        }
        );

=cut

sub push_link
{
    my ($self, $params) = @_;

    my $content = [
        type        => 'link',
        device_iden => $params->{device_iden},
        title       => $params->{title},
        url         => $params->{url},
    ];
    $self->DEBUG(sprintf('push_link: %s', dump($content)));
    my $result = $self->_pushes($content);

    return ($result);
}

=head2 push_list($params)

Pushes list (with title & items)

    $pb->push_list(
        {
            device_iden => $device_iden,
            title       => 'One list with 3 items',
            items       => [ 'One', 'Two', 'Three' ]
        }
        );

=cut

sub push_list
{
    my ($self, $params) = @_;

    my $content = [
        type        => 'list',
        device_iden => $params->{device_iden},
        title       => $params->{title},
        items       => $params->{items},
    ];
    $self->DEBUG(sprintf('push_list: %s', dump($content)));
    my $result = $self->_pushes($content);

    return ($result);
}

=head2 push_note($params)

Pushes note (with title & body)

    $pb->push_note(
        {
            device_iden => $device_iden,
            title       => 'Note Title',
            body        => 'Note Body'
        }
        );

=cut

sub push_note
{
    my ($self, $params) = @_;

    my $content = [
        type        => 'note',
        device_iden => $params->{device_iden},
        title       => $params->{title},
        body        => $params->{body},
    ];
    $self->DEBUG(sprintf('push_note: %s', dump($content)));
    my $result = $self->_pushes($content);

    return ($result);
}

=head2 version()

Returns WWW::PushBullet module version

=cut

sub version
{
    return ($VERSION);
}

1;

=head1 LICENSE
 
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REPOSITORY

L<https://github.com/sebthebert/WWW-PushBullet>

=head1 AUTHOR

Sebastien Thebert <www-pushbullet@onetool.pm>

=cut
