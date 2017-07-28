package PONAPI::Client::UA::Hijk;

################################################################################
################################################################################

use strict;
use warnings;

use Moose;
use Hijk;

use constant OLD_HIJK => $Hijk::VERSION lt '0.16';

################################################################################
################################################################################

sub send_http_request {
    $_[1]->{parse_chunked} = 1;
    return Hijk::request($_[1]);
}

################################################################################
################################################################################

sub before_request { }

################################################################################
################################################################################

sub after_request {
    my ($self, $response) = @_;

    if ( OLD_HIJK ) {
        if ( ($response->{head}{'Transfer-Encoding'}||'') eq 'chunked' ) {
            die "Got a chunked response from the server, but this version of Hijk can't handle those; please upgrade to at least Hijk 0.16";
        }
    }
}
################################################################################
################################################################################

no Moose;
__PACKAGE__->meta->make_immutable();

1;

################################################################################
################################################################################

